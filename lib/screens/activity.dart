import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'txn_editor.dart';

enum _Scope { month, all }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _search = TextEditingController();
  _Scope _scope = _Scope.month;
  TxType? _type;
  final Set<String> _cats = {};

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickCategories() async {
    final store = context.read<AppStore>();
    final picked = {..._cats};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(children: [
                  Expanded(child: Text('Filter by category', style: ctx.tt.titleLarge)),
                  TextButton(onPressed: () => setSheet(picked.clear), child: const Text('Clear')),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    for (final c in store.categories.where((c) => _type == null || c.type == _type))
                      CheckboxListTile(
                        value: picked.contains(c.id),
                        onChanged: (v) => setSheet(() => v! ? picked.add(c.id) : picked.remove(c.id)),
                        secondary: CategoryAvatar.of(c, size: 36),
                        title: Text(c.name),
                        subtitle: Text(c.type == TxType.expense ? 'Expense' : 'Income'),
                      ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Apply')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() {
      _cats
        ..clear()
        ..addAll(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    final q = _search.text.trim().toLowerCase();
    final source = _scope == _Scope.month ? store.current.txns : store.txnsSorted;
    final list = source.where((t) {
      if (_type != null && t.type != _type) return false;
      if (_cats.isNotEmpty && !_cats.contains(t.categoryId)) return false;
      if (q.isNotEmpty) {
        final c = store.categoryById(t.categoryId).name.toLowerCase();
        final hay = '${t.note.toLowerCase()} $c ${t.method.toLowerCase()} ${t.amount}';
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    final spent = list.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final earned = list.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);

    // Flatten into day headers + rows.
    final items = <Object>[];
    DateTime? day;
    final dayTotals = <DateTime, double>{};
    for (final t in list) {
      final d = dateOnly(t.date);
      dayTotals[d] = (dayTotals[d] ?? 0) + t.signed;
      if (d != day) {
        items.add(d);
        day = d;
      }
      items.add(t);
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Activity'),
          titleSpacing: 20,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(118),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SearchBar(
                    controller: _search,
                    hintText: 'Search notes, categories, amounts',
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(context.cs.surfaceContainerHigh),
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.search_rounded),
                    ),
                    trailing: [
                      if (_search.text.isNotEmpty)
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: _search.clear),
                    ],
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    children: [
                      FilterChip(
                        label: Text(_scope == _Scope.month ? 'This month' : 'All time'),
                        avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
                        selected: true,
                        onSelected: (_) =>
                            setState(() => _scope = _scope == _Scope.month ? _Scope.all : _Scope.month),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Expenses'),
                        selected: _type == TxType.expense,
                        onSelected: (v) => setState(() => _type = v ? TxType.expense : null),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Income'),
                        selected: _type == TxType.income,
                        onSelected: (v) => setState(() => _type = v ? TxType.income : null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(_cats.isEmpty ? 'Categories' : '${_cats.length} categories'),
                        selected: _cats.isNotEmpty,
                        onSelected: (_) => _pickCategories(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              '${list.length} transaction${list.length == 1 ? '' : 's'} · '
              'Spent ${fmt.money(spent)} · Earned ${fmt.money(earned)}',
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: source.isEmpty ? 'Nothing here yet' : 'No matches',
              message: source.isEmpty ? 'Transactions you add will show up here.' : 'Try a different search or filter.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 120),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                if (it is DateTime) {
                  final total = dayTotals[it]!;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(dayLabel(it),
                            style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant)),
                      ),
                      Text(
                        '${total < 0 ? '−' : '+'}${fmt.money(total.abs())}',
                        style: context.tt.labelMedium?.copyWith(
                          color: context.cs.onSurfaceVariant,
                          fontFeatures: tabular,
                        ),
                      ),
                    ]),
                  );
                }
                final t = it as Txn;
                return Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: context.cs.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.delete_rounded, color: context.cs.onErrorContainer),
                  ),
                  onDismissed: (_) => deleteTxnWithUndo(context, t),
                  child: TxnTile(
                    txn: t,
                    showDate: false,
                    onTap: () => openTxnEditor(context, txn: t),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
