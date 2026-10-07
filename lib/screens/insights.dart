import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../catalog.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'txn_editor.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String? _cycleId;
  TxType _type = TxType.expense;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cycles = store.cyclesDesc;
    final cycle = cycles.firstWhere((c) => c.id == _cycleId, orElse: () => store.activeCycle);
    final s = store.stats(cycle);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Insights'),
          titleSpacing: 20,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                itemCount: cycles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final st = store.stats(cycles[i]);
                  return ChoiceChip(
                    label: Text(i == 0 ? 'This month' : cycleName(st.start, st.end)),
                    selected: cycles[i].id == cycle.id,
                    onSelected: (_) => setState(() => _cycleId = cycles[i].id),
                  );
                },
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList.list(
            children: [InsightsBody(stats: s, type: _type, onType: (t) => setState(() => _type = t))],
          ),
        ),
      ],
    );
  }
}

/// Charts and highlights for one cycle. Reused by the month detail screen.
class InsightsBody extends StatelessWidget {
  const InsightsBody({super.key, required this.stats, required this.type, required this.onType, this.showTrend = true});

  final CycleStats stats;
  final TxType type;
  final ValueChanged<TxType> onType;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    final s = stats;
    final data = type == TxType.expense ? s.byCategory : s.incomeByCategory;
    final total = type == TxType.expense ? s.expense : s.income;
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final counts = <String, int>{};
    for (final t in s.txns.where((t) => t.type == type)) {
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
    }
    final slices = [for (final e in entries) DonutSlice(store.categoryById(e.key), e.value)];

    final idx = store.cycles.indexOf(s.cycle);
    final trend = [for (var i = (idx - 5).clamp(0, idx); i <= idx; i++) store.stats(store.cycles[i])];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatChip(label: 'Spent', value: fmt.money(s.expense)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatChip(label: 'Earned', value: fmt.money(s.income)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatChip(label: 'Saved · ${pct(s.savingsRate)}', value: fmt.money(s.saved)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('By category', style: context.tt.titleMedium)),
                    SegmentedButton<TxType>(
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: TxType.expense, label: Text('Spent')),
                        ButtonSegment(value: TxType.income, label: Text('Income')),
                      ],
                      selected: {type},
                      onSelectionChanged: (v) => onType(v.first),
                    ),
                  ],
                ),
                if (slices.isEmpty)
                  const EmptyState(icon: Icons.donut_large_rounded, title: 'No data for this month')
                else ...[
                  const SizedBox(height: 12),
                  CategoryDonut(slices: slices, centerLabel: type == TxType.expense ? 'Total spent' : 'Total income'),
                  const SizedBox(height: 12),
                  for (final e in entries)
                    Builder(
                      builder: (context) {
                        final c = store.categoryById(e.key);
                        final budget = type == TxType.expense ? c.budget : null;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryTxnsScreen(cycleId: s.cycle.id, categoryId: e.key, type: type),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                CategoryAvatar.of(c, size: 38),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: context.tt.titleSmall),
                                      Text(
                                        '${counts[e.key] ?? 0} txns'
                                        '${budget != null ? ' · ${pct(e.value / budget)} of ${fmt.money(budget)}' : ''}',
                                        style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      fmt.money(e.value),
                                      style: context.tt.titleSmall?.copyWith(fontFeatures: tabular),
                                    ),
                                    Text(
                                      pct(total == 0 ? 0 : e.value / total),
                                      style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, size: 20, color: context.cs.onSurfaceVariant),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily spending', style: context.tt.titleMedium),
                const SizedBox(height: 2),
                Text(
                  s.budget > 0
                      ? 'Dashed line is your even daily budget of ${fmt.money(s.budget / s.totalDays)}'
                      : 'Average ${fmt.money(s.dailyAverage)} per day',
                  style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                DailyBars(stats: s),
              ],
            ),
          ),
        ),
        if (showTrend && trend.length > 1) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Month over month', style: context.tt.titleMedium)),
                      _Legend(color: context.incomeColor, label: 'Income'),
                      const SizedBox(width: 12),
                      _Legend(color: context.cs.primary, label: 'Spent'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TrendBars(cycles: trend, selectedId: s.cycle.id),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        SectionHeader('Highlights', padding: const EdgeInsets.fromLTRB(4, 20, 4, 8)),
        _Highlights(stats: s),
      ],
    );
  }
}

/// Transactions of one category within one cycle, opened from "By category".
class CategoryTxnsScreen extends StatelessWidget {
  const CategoryTxnsScreen({super.key, required this.cycleId, required this.categoryId, required this.type});

  final String cycleId;
  final String categoryId;
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    final c = store.categoryById(categoryId);
    final cycle = store.cycles.where((x) => x.id == cycleId).firstOrNull;
    if (cycle == null) {
      // The cycle was merged away (undo reset) while open.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This month no longer exists.')),
      );
    }
    final s = store.stats(cycle);
    final txns = s.txns.where((t) => t.categoryId == categoryId && t.type == type).toList();
    final sum = txns.fold<double>(0, (a, t) => a + t.amount);

    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Row(
            children: [
              CategoryAvatar.of(c, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmt.money(sum), style: context.tt.headlineSmall?.copyWith(fontFeatures: tabular)),
                    Text(
                      '${txns.length} txns · ${s.isActive ? 'This month' : cycleName(s.start, s.end)}',
                      style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (txns.isEmpty)
            const EmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions')
          else
            Card(
              child: Column(
                children: [
                  for (final t in txns)
                    TxnTile(
                      txn: t,
                      showDate: true,
                      onTap: () => openTxnEditor(context, txn: t),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.tt.labelSmall),
    ],
  );
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    final s = stats;
    final prev = store.previousOf(s.cycle);

    final weekday = List<double>.filled(7, 0);
    for (final t in s.txns.where((t) => t.isExpense)) {
      weekday[t.date.weekday - 1] += t.amount;
    }
    var busiest = -1;
    for (var i = 0; i < 7; i++) {
      if (weekday[i] > 0 && (busiest < 0 || weekday[i] > weekday[busiest])) busiest = i;
    }
    final topMethod = (s.byMethod.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).firstOrNull;

    final items = <_Insight>[
      if (prev != null && prev.expense > 0)
        _Insight(
          icon: s.expense <= prev.expense ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          color: s.expense <= prev.expense ? context.incomeColor : context.expenseColor,
          title:
              '${pct(((s.expense - prev.expense) / prev.expense).abs())} ${s.expense <= prev.expense ? 'less' : 'more'}',
          subtitle: 'spent than ${cycleName(prev.start, prev.end)}${s.isActive ? ' so far' : ''}',
        ),
      if (s.isActive && s.expense > 0)
        _Insight(
          icon: Icons.insights_rounded,
          color: s.budget > 0 && s.projected > s.budget ? context.expenseColor : context.cs.primary,
          title: fmt.money(s.projected.roundToDouble()),
          subtitle: s.budget > 0
              ? 'projected spend · ${s.projected > s.budget ? 'over' : 'within'} budget'
              : 'projected spend at this pace',
        ),
      if (s.biggest != null)
        _Insight(
          icon: Icons.local_fire_department_rounded,
          color: Colors.orange,
          title: fmt.money(s.biggest!.amount),
          subtitle:
              'biggest: ${s.biggest!.note.isNotEmpty ? s.biggest!.note : store.categoryById(s.biggest!.categoryId).name}',
        ),
      if (busiest >= 0)
        _Insight(
          icon: Icons.calendar_view_week_rounded,
          color: context.cs.tertiary,
          title: DateFormat('EEEE').format(DateTime(2024, 1, busiest + 1)),
          subtitle: 'your heaviest spending day (${fmt.compact(weekday[busiest])})',
        ),
      if (topMethod != null)
        _Insight(
          icon: methodIcon(topMethod.key),
          color: context.cs.secondary,
          title: topMethod.key,
          subtitle: '${pct(s.expense == 0 ? 0 : topMethod.value / s.expense)} of spending',
        ),
      if (s.income > 0)
        _Insight(
          icon: Icons.savings_rounded,
          color: s.saved >= 0 ? context.incomeColor : context.expenseColor,
          title: pct(s.savingsRate),
          subtitle: s.saved >= 0 ? 'of income saved' : 'more spent than earned',
        ),
    ];

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Add a few transactions to unlock insights.',
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      padding: EdgeInsets.zero,
      children: [for (final i in items) _InsightCard(i)],
    );
  }
}

class _Insight {
  _Insight({required this.icon, required this.color, required this.title, required this.subtitle});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard(this.i);
  final _Insight i;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: i.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(i.icon, size: 18, color: i.color),
            ),
            const Spacer(),
            Text(
              i.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
            ),
            const SizedBox(height: 2),
            Text(
              i.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
