import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'insights.dart';
import 'new_cycle.dart';
import 'txn_editor.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    final all = store.cyclesDesc.map(store.stats).toList();
    final current = all.first;
    final past = all.skip(1).toList();
    final avgSpend = past.isEmpty ? 0.0 : past.fold(0.0, (s, x) => s + x.expense) / past.length;
    final totalSaved = all.fold(0.0, (s, x) => s + x.saved);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Months'), titleSpacing: 20),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList.list(children: [
            Card(
              color: context.cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.cs.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('IN PROGRESS',
                            style: context.tt.labelSmall?.copyWith(color: context.cs.onPrimary, letterSpacing: 0.8)),
                      ),
                      const Spacer(),
                      Text('Day ${current.elapsedDays}',
                          style: context.tt.labelLarge?.copyWith(color: context.cs.onPrimaryContainer)),
                    ]),
                    const SizedBox(height: 14),
                    Text(cycleName(current.start, current.end),
                        style: context.tt.headlineSmall?.copyWith(color: context.cs.onPrimaryContainer)),
                    Text('Started ${longDate(current.start)}',
                        style: context.tt.bodyMedium?.copyWith(
                            color: context.cs.onPrimaryContainer.withValues(alpha: 0.75))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => openCycleDetail(context, current.cycle),
                          child: const Text('Details'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: () => startNewCycleFlow(context),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('New month'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            if (past.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatChip(label: 'Months logged', value: '${all.length}', icon: Icons.history_rounded)),
                const SizedBox(width: 10),
                Expanded(
                  child: StatChip(label: 'Avg. monthly spend', value: fmt.compact(avgSpend), icon: Icons.functions_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatChip(
                    label: 'Total saved',
                    value: fmt.compact(totalSaved),
                    icon: Icons.savings_rounded,
                    color: totalSaved >= 0 ? context.incomeColor : context.expenseColor,
                  ),
                ),
              ]),
              SectionHeader('Past months', padding: const EdgeInsets.fromLTRB(4, 24, 4, 8)),
              for (final s in past) ...[_MonthCard(stats: s), const SizedBox(height: 10)],
            ] else
              const EmptyState(
                icon: Icons.calendar_month_rounded,
                title: 'Your month logs live here',
                message: 'When you start a new month, the finished one is archived here with its full breakdown.',
              ),
          ]),
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    final s = stats;
    final hasBudget = s.budget > 0;
    final under = s.expense <= s.budget;
    return Pressable(
      onTap: () => openCycleDetail(context, s.cycle),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cycleName(s.start, s.end), style: context.tt.titleMedium),
                    Text('${rangeLabel(s.start, s.end)} · ${s.totalDays} days',
                        style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
                  ]),
                ),
                if (hasBudget)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (under ? context.incomeColor : context.expenseColor).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      under ? 'Under budget' : 'Over budget',
                      style: context.tt.labelSmall?.copyWith(
                        color: under ? context.incomeColor : context.expenseColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _Fig(label: 'Spent', value: fmt.money(s.expense)),
                _Fig(label: 'Earned', value: fmt.money(s.income)),
                _Fig(
                  label: 'Saved',
                  value: fmt.money(s.saved),
                  color: s.saved >= 0 ? context.incomeColor : context.expenseColor,
                ),
              ]),
              if (hasBudget) ...[
                const SizedBox(height: 12),
                Bar(value: s.budgetUsed, height: 6),
                const SizedBox(height: 6),
                Text('${pct(s.budgetUsed)} of ${fmt.money(s.budget)} budget',
                    style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.tt.titleSmall?.copyWith(fontFeatures: tabular, color: color)),
          ),
        ]),
      );
}

void openCycleDetail(BuildContext context, Cycle c) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => CycleDetailScreen(cycleId: c.id)));
}

class CycleDetailScreen extends StatefulWidget {
  const CycleDetailScreen({super.key, required this.cycleId});
  final String cycleId;

  @override
  State<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends State<CycleDetailScreen> {
  TxType _type = TxType.expense;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cycle = store.cycles.where((c) => c.id == widget.cycleId).firstOrNull;
    if (cycle == null) {
      // The cycle was merged away (undo reset) while open.
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('This month no longer exists.')));
    }
    final s = store.stats(cycle);
    final fmt = store.fmt;
    final idx = store.cycles.indexOf(cycle);
    final isActive = s.isActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(cycleName(s.start, s.end)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'budget':
                  final b = await askAmount(context, title: 'Budget', initial: cycle.budget);
                  if (b != null) store.updateCycle(cycle, budget: b);
                case 'start':
                  final first = idx > 0 ? store.cycles[idx - 1].start.add(const Duration(days: 1)) : DateTime(2000);
                  final last = isActive ? dateOnly(DateTime.now()) : store.cycles[idx + 1].start.subtract(const Duration(days: 1));
                  final d = await pickDate(context, cycle.start, first: first, last: last);
                  if (d != null) store.updateCycle(cycle, start: d);
                case 'merge':
                  if (!context.mounted) return;
                  final ok = await confirm(
                    context,
                    title: 'Merge into previous month?',
                    message: 'This undoes the reset. Its transactions become part of the previous month.',
                    confirmLabel: 'Merge',
                  );
                  if (ok && context.mounted) {
                    Navigator.pop(context);
                    store.undoLastReset();
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'budget', child: Text('Edit budget')),
              const PopupMenuItem(value: 'start', child: Text('Change start date')),
              if (isActive && store.cycles.length > 1)
                const PopupMenuItem(value: 'merge', child: Text('Undo reset (merge)')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Text(
            '${rangeLabel(s.start, s.end)}${isActive ? ' (projected)' : ''}',
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Opening ${fmt.money(cycle.openingBalance)} → ${isActive ? 'current' : 'closing'} ${fmt.money(s.balance)}',
            style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          InsightsBody(stats: s, type: _type, onType: (t) => setState(() => _type = t), showTrend: false),
          SectionHeader('Transactions (${s.txns.length})', padding: const EdgeInsets.fromLTRB(4, 24, 4, 8)),
          if (s.txns.isEmpty)
            const EmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions')
          else
            Card(
              child: Column(children: [
                for (final t in s.txns)
                  TxnTile(txn: t, showDate: true, onTap: () => openTxnEditor(context, txn: t)),
              ]),
            ),
        ],
      ),
    );
  }
}
