import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../catalog.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

Future<void> editMonthlyBudget(BuildContext context) async {
  final store = context.read<AppStore>();
  final v = await askAmount(
    context,
    title: 'Monthly budget',
    hint: 'How much you plan to spend this month',
    initial: store.activeCycle.budget,
  );
  if (v != null) store.updateCycle(store.activeCycle, budget: v);
}

Future<void> editCategoryBudget(BuildContext context, Category c) async {
  final store = context.read<AppStore>();
  final v = await askAmount(
    context,
    title: '${c.name} budget',
    hint: 'Monthly limit for this category',
    initial: c.budget,
    allowClear: c.budget != null,
  );
  if (v != null) store.setCategoryBudget(c.id, v);
}

Future<Category?> pickCategory(BuildContext context, TxType type, {bool Function(Category)? where}) {
  final store = context.read<AppStore>();
  final cats = store.categoriesOf(type).where(where ?? (_) => true).toList();
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text('Choose category', style: ctx.tt.titleLarge),
          ),
          if (cats.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Every category already has a budget.')),
          for (final c in cats)
            ListTile(
              leading: CategoryAvatar.of(c, size: 40),
              title: Text(c.name),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    ),
  );
}

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(builder: (context) {
        final tabs = DefaultTabController.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plan'),
            titleSpacing: 20,
            bottom: const TabBar(
              dividerColor: Colors.transparent,
              tabs: [Tab(text: 'Budgets'), Tab(text: 'Goals'), Tab(text: 'Recurring')],
            ),
          ),
          floatingActionButton: ListenableBuilder(
            listenable: tabs,
            builder: (context, _) => FloatingActionButton.extended(
              heroTag: 'plan',
              icon: const Icon(Icons.add_rounded),
              label: Text(const ['Budget', 'Goal', 'Recurring'][tabs.index]),
              onPressed: () async {
                switch (tabs.index) {
                  case 0:
                    final c = await pickCategory(context, TxType.expense, where: (c) => c.budget == null);
                    if (c != null && context.mounted) await editCategoryBudget(context, c);
                  case 1:
                    await editGoal(context);
                  case 2:
                    await editRecurring(context);
                }
              },
            ),
          ),
          body: const TabBarView(children: [_BudgetsTab(), _GoalsTab(), _RecurringTab()]),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------- budgets

class _BudgetsTab extends StatelessWidget {
  const _BudgetsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.current;
    final fmt = store.fmt;
    final withBudget = store.categoriesOf(TxType.expense).where((c) => c.budget != null).toList()
      ..sort((a, b) => ((s.byCategory[b.id] ?? 0) / b.budget!).compareTo((s.byCategory[a.id] ?? 0) / a.budget!));
    final allocated = withBudget.fold(0.0, (sum, c) => sum + c.budget!);
    final over = s.budget > 0 && s.expense > s.budget;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Pressable(
          onTap: () => editMonthlyBudget(context),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Ring(
                    value: s.budgetUsed,
                    size: 84,
                    stroke: 9,
                    color: over ? context.expenseColor : context.cs.primary,
                    child: Text(s.budget > 0 ? pct(s.budgetUsed) : '—', style: context.tt.titleMedium),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly budget',
                            style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant)),
                        Text(s.budget > 0 ? fmt.money(s.budget) : 'Not set',
                            style: context.tt.headlineSmall?.copyWith(fontFeatures: tabular)),
                        const SizedBox(height: 4),
                        Text(
                          s.budget <= 0
                              ? 'Tap to set one'
                              : over
                                  ? '${fmt.money(-s.budgetLeft)} over'
                                  : '${fmt.money(s.budgetLeft)} left · ${fmt.compact(s.safeDaily)}/day',
                          style: context.tt.bodySmall?.copyWith(
                            color: over ? context.expenseColor : context.cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_rounded, size: 18, color: context.cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        SectionHeader('Category budgets', padding: const EdgeInsets.fromLTRB(4, 24, 4, 8)),
        if (withBudget.isEmpty)
          const EmptyState(
            icon: Icons.pie_chart_outline_rounded,
            title: 'No category limits',
            message: 'Cap categories like Food or Shopping and get warned when you near the limit.',
          )
        else ...[
          Card(child: Column(children: [for (final c in withBudget) BudgetRow(category: c, spent: s.byCategory[c.id] ?? 0)])),
          if (s.budget > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Text(
                '${fmt.money(allocated)} of ${fmt.money(s.budget)} allocated to categories',
                style: context.tt.bodySmall?.copyWith(
                  color: allocated > s.budget ? context.expenseColor : context.cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class BudgetRow extends StatelessWidget {
  const BudgetRow({super.key, required this.category, required this.spent});

  final Category category;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    final b = category.budget!;
    final ratio = spent / b;
    final color = ratio >= 1
        ? context.expenseColor
        : ratio >= 0.8
            ? Colors.orange
            : category.colorValue;
    return InkWell(
      onTap: () => editCategoryBudget(context, category),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            CategoryAvatar.of(category, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(category.name, style: context.tt.titleSmall)),
                    Text(
                      ratio >= 1 ? '${fmt.money(spent - b)} over' : '${fmt.money(b - spent)} left',
                      style: context.tt.labelMedium?.copyWith(color: ratio >= 0.8 ? color : null),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Bar(value: ratio, color: color, height: 7),
                  const SizedBox(height: 6),
                  Text(
                    '${fmt.money(spent)} of ${fmt.money(b)}',
                    style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant, fontFeatures: tabular),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- goals

class _GoalsTab extends StatelessWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    if (store.goals.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          icon: Icons.savings_rounded,
          title: 'Save toward something',
          message: 'Create goals like an emergency fund, a trip or a new phone, and track every rupee you set aside.',
        ),
      );
    }
    final saved = store.goals.fold(0.0, (s, g) => s + g.saved);
    final target = store.goals.fold(0.0, (s, g) => s + g.target);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text('${fmt.money(saved)} saved of ${fmt.money(target)}',
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (final g in store.goals) ...[_GoalCard(goal: g), const SizedBox(height: 12)],
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  Future<void> _adjust(BuildContext context, bool add) async {
    final store = context.read<AppStore>();
    final v = await askAmount(
      context,
      title: add ? 'Add to ${goal.name}' : 'Withdraw from ${goal.name}',
      confirmLabel: add ? 'Add' : 'Withdraw',
    );
    if (v == null || v <= 0) return;
    store.adjustGoal(goal, add ? v : -v);
    HapticFeedback.lightImpact();
    if (add && goal.saved >= goal.target && context.mounted) toast(context, '🎉 ${goal.name} reached!');
  }

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    final g = goal;
    final color = Color(g.color);
    final done = g.saved >= g.target;
    String? pace;
    if (g.deadline != null && !done) {
      final months = (g.deadline!.difference(DateTime.now()).inDays / 30.4).ceil();
      pace = months <= 0
          ? 'Deadline passed'
          : '${fmt.money(((g.target - g.saved) / months).ceilToDouble())}/month to reach by ${shortDate(g.deadline!)}';
    }
    return Pressable(
      onTap: () => editGoal(context, goal: g),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Ring(
                    value: g.progress,
                    color: color,
                    size: 56,
                    child: Icon(iconFor(g.icon), color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name, style: context.tt.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${fmt.money(g.saved)} of ${fmt.money(g.target)}',
                          style: context.tt.bodyMedium?.copyWith(fontFeatures: tabular),
                        ),
                      ],
                    ),
                  ),
                  Text(done ? 'Done' : pct(g.progress),
                      style: context.tt.titleMedium?.copyWith(color: color)),
                ],
              ),
              if (pace != null) ...[
                const SizedBox(height: 10),
                Text(pace, style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: g.saved > 0 ? () => _adjust(context, false) : null,
                      icon: const Icon(Icons.remove_rounded),
                      label: const Text('Withdraw'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () => _adjust(context, true),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add money'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> editGoal(BuildContext context, {Goal? goal}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GoalSheet(goal: goal),
  );
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({this.goal});
  final Goal? goal;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final _name = TextEditingController(text: widget.goal?.name ?? '');
  late final _target = TextEditingController(
    text: widget.goal == null ? '' : widget.goal!.target.toStringAsFixed(0),
  );
  late String _icon = widget.goal?.icon ?? 'savings';
  late int _color = widget.goal?.color ?? kPalette[5];
  late DateTime? _deadline = widget.goal?.deadline;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  void _save() {
    final target = double.tryParse(_target.text) ?? 0;
    if (_name.text.trim().isEmpty || target <= 0) {
      toast(context, 'Add a name and target amount');
      return;
    }
    final g = widget.goal;
    context.read<AppStore>().upsertGoal(Goal(
          id: g?.id ?? newId(),
          name: _name.text.trim(),
          target: target,
          saved: g?.saved ?? 0,
          icon: _icon,
          color: _color,
          deadline: _deadline,
        ));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final store = context.read<AppStore>();
    final nav = Navigator.of(context);
    final ok = await confirm(context,
        title: 'Delete goal?', message: 'This removes the goal and its saved amount.', confirmLabel: 'Delete', destructive: true);
    if (ok) {
      store.deleteGoal(widget.goal!);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(widget.goal == null ? 'New goal' : 'Edit goal', style: context.tt.titleLarge)),
              if (widget.goal != null)
                IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  final i = await pickIcon(context, _icon, Color(_color));
                  if (i != null) setState(() => _icon = i);
                },
                child: CategoryAvatar(icon: _icon, color: Color(_color), size: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: widget.goal == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Goal name'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(prefixText: store.fmt.currency.symbol, hintText: 'Target amount'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              InputChip(
                avatar: const Icon(Icons.flag_rounded, size: 18),
                label: Text(_deadline == null ? 'Add target date' : 'By ${longDate(_deadline!)}'),
                onPressed: () async {
                  final d = await pickDate(context, _deadline ?? addMonth(DateTime.now(), 6), first: DateTime.now());
                  if (d != null) setState(() => _deadline = d);
                },
                onDeleted: _deadline == null ? null : () => setState(() => _deadline = null),
              ),
            ]),
            const SizedBox(height: 16),
            ColorRow(colors: kPalette, selected: _color, onSelect: (c) => setState(() => _color = c)),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save goal')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- recurring

class _RecurringTab extends StatelessWidget {
  const _RecurringTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    if (store.recurring.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          icon: Icons.autorenew_rounded,
          title: 'Automate the regulars',
          message: 'Rent, subscriptions, EMIs or your salary — they\'ll be logged automatically each month.',
        ),
      );
    }
    final list = [...store.recurring]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final income = store.recurring.where((r) => r.active && r.type == TxType.income).fold(0.0, (s, r) => s + r.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Row(children: [
          Expanded(
            child: StatChip(
              icon: Icons.north_east_rounded,
              label: 'Fixed costs / month',
              value: fmt.money(store.monthlyRecurringExpense),
              color: context.expenseColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatChip(
              icon: Icons.south_west_rounded,
              label: 'Fixed income / month',
              value: fmt.money(income),
              color: context.incomeColor,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            for (final r in list)
              Builder(builder: (context) {
                final c = store.categoryById(r.categoryId);
                return ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  leading: Opacity(opacity: r.active ? 1 : 0.4, child: CategoryAvatar.of(c, size: 42)),
                  title: Text(r.name.isEmpty ? c.name : r.name),
                  subtitle: Text(
                    r.active ? 'Monthly on day ${r.dayOfMonth} · next ${dayLabel(r.nextDue)}' : 'Paused',
                  ),
                  onTap: () => editRecurring(context, r: r),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '${r.type == TxType.expense ? '−' : '+'}${fmt.money(r.amount)}',
                      style: context.tt.titleSmall?.copyWith(
                        fontFeatures: tabular,
                        color: r.type == TxType.income ? context.incomeColor : null,
                      ),
                    ),
                    Switch(
                      value: r.active,
                      onChanged: (v) {
                        r.active = v;
                        if (v) {
                          // Resume from the next future occurrence rather than back-filling.
                          final today = dateOnly(DateTime.now());
                          var next = DateTime(today.year, today.month, 1);
                          next = addMonth(next, 0, r.dayOfMonth);
                          if (next.isBefore(today)) next = addMonth(next, 1, r.dayOfMonth);
                          r.nextDue = next;
                        }
                        store.upsertRecurring(r);
                      },
                    ),
                  ]),
                );
              }),
          ]),
        ),
      ],
    );
  }
}

Future<void> editRecurring(BuildContext context, {Recurring? r}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RecurringSheet(r: r),
  );
}

class _RecurringSheet extends StatefulWidget {
  const _RecurringSheet({this.r});
  final Recurring? r;

  @override
  State<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<_RecurringSheet> {
  late TxType _type = widget.r?.type ?? TxType.expense;
  late final _name = TextEditingController(text: widget.r?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.r == null ? '' : widget.r!.amount.toStringAsFixed(widget.r!.amount % 1 == 0 ? 0 : 2),
  );
  late String? _categoryId = widget.r?.categoryId;
  late DateTime _next = widget.r?.nextDue ?? dateOnly(DateTime.now());
  late String _method = widget.r?.method ?? 'UPI';

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0 || _categoryId == null || _name.text.trim().isEmpty) {
      toast(context, 'Add a name, amount and category');
      return;
    }
    final old = widget.r;
    final messenger = ScaffoldMessenger.of(context);
    context.read<AppStore>().upsertRecurring(Recurring(
          id: old?.id ?? newId(),
          type: _type,
          amount: amount,
          categoryId: _categoryId!,
          name: _name.text.trim(),
          dayOfMonth: _next.day,
          nextDue: dateOnly(_next),
          method: _method,
          active: old?.active ?? true,
        ));
    Navigator.pop(context);
    if (!dateOnly(_next).isAfter(dateOnly(DateTime.now()))) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Due today or earlier, so it was added to your transactions')),
      );
    }
  }

  Future<void> _delete() async {
    final store = context.read<AppStore>();
    final nav = Navigator.of(context);
    final ok = await confirm(context,
        title: 'Delete recurring item?',
        message: 'Past transactions stay. Future ones won\'t be added.',
        confirmLabel: 'Delete',
        destructive: true);
    if (ok) {
      store.deleteRecurring(widget.r!);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cat = _categoryId == null ? null : store.categoryById(_categoryId!);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(widget.r == null ? 'New recurring' : 'Edit recurring', style: context.tt.titleLarge),
              ),
              if (widget.r != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
            ]),
            const SizedBox(height: 16),
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('Expense')),
                ButtonSegment(value: TxType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: _type == TxType.expense ? 'e.g. Netflix, Rent' : 'e.g. Salary'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(prefixText: store.fmt.currency.symbol, hintText: 'Amount'),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: context.theme.inputDecorationTheme.fillColor,
              leading: cat == null ? const Icon(Icons.category_rounded) : CategoryAvatar.of(cat, size: 36),
              title: Text(cat?.name ?? 'Choose category'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final c = await pickCategory(context, _type);
                if (c != null) setState(() => _categoryId = c.id);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: context.theme.inputDecorationTheme.fillColor,
              leading: const Icon(Icons.event_repeat_rounded),
              title: Text('Next on ${longDate(_next)}'),
              subtitle: Text('Repeats monthly on day ${_next.day}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final d = await pickDate(context, _next, first: DateTime.now().subtract(const Duration(days: 60)));
                if (d != null) setState(() => _next = d);
              },
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in kMethods)
                ChoiceChip(
                  label: Text(m),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ]),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
