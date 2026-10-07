import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'new_cycle.dart';
import 'plan.dart';
import 'settings.dart';
import 'shell.dart';
import 'txn_editor.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.current;
    final fmt = store.fmt;
    final name = store.settings.name;
    final recent = s.txns.take(6).toList();
    final upcoming = store.upcoming();
    final alerts = store
        .categoriesOf(TxType.expense)
        .where((c) => c.budget != null && (s.byCategory[c.id] ?? 0) >= c.budget! * 0.8)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 72,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? greeting() : '${greeting()}, $name',
                style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant),
              ),
              Text(cycleName(s.start, s.end), style: context.tt.headlineSmall),
            ],
          ),
          actions: [
            IconButton(
              tooltip: store.settings.hideAmounts ? 'Show amounts' : 'Hide amounts',
              icon: Icon(store.settings.hideAmounts ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => store.updateSettings((x) => x.hideAmounts = !x.hideAmounts),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(children: [
            _HeroCard(stats: s),
            if (store.cycleOverdue) ...[
              const SizedBox(height: 12),
              _OverdueBanner(days: store.activeCycleAgeDays),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (s.budget > 0) ...[
                  Expanded(
                    child: StatChip(
                      icon: Icons.shield_moon_rounded,
                      label: 'Safe / day',
                      value: fmt.compact(s.safeDaily),
                      color: s.budgetLeft < 0 ? context.expenseColor : context.incomeColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: StatChip(
                    icon: Icons.speed_rounded,
                    label: 'Daily average',
                    value: fmt.compact(s.dailyAverage),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatChip(
                    icon: Icons.hourglass_bottom_rounded,
                    label: store.cycleOverdue ? 'Days in' : 'Days left',
                    value: store.cycleOverdue ? '${s.elapsedDays}' : '${s.daysLeft}',
                    color: context.cs.tertiary,
                  ),
                ),
              ],
            ),
          ]),
        ),
        if (alerts.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader('Budget alerts', action: 'Budgets', onAction: () => Shell.goTo(context, 3)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(children: [
              Card(
                child: Column(children: [
                  for (final c in alerts) BudgetRow(category: c, spent: s.byCategory[c.id] ?? 0),
                ]),
              ),
            ]),
          ),
        ],
        if (s.byCategory.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader('Where it\'s going', action: 'Insights', onAction: () => Shell.goTo(context, 2)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _TopCategories(stats: s)),
          ),
        ],
        if (upcoming.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('Coming up')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: upcoming.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _UpcomingCard(r: upcoming[i]),
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: SectionHeader(
            'Recent',
            action: s.txns.length > recent.length ? 'See all' : null,
            onAction: () => Shell.goTo(context, 1),
          ),
        ),
        if (recent.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No transactions yet',
              message: 'Add your first expense or income for this month.',
              action: FilledButton.tonalIcon(
                onPressed: () => openTxnEditor(context, type: TxType.income),
                icon: const Icon(Icons.south_west_rounded),
                label: const Text('Add income'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList.builder(
              itemCount: recent.length,
              itemBuilder: (_, i) => TxnTile(
                txn: recent[i],
                showDate: true,
                onTap: () => openTxnEditor(context, txn: recent[i]),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    final s = stats;
    final cs = context.cs;
    final over = s.budget > 0 && s.expense > s.budget;
    const fg = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.72);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(cs.primary, Colors.black, context.isDark ? 0.25 : 0.05)!,
            Color.lerp(cs.tertiary, Colors.black, context.isDark ? 0.35 : 0.15)!,
          ],
        ),
        boxShadow: [
          BoxShadow(color: cs.primary.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Spent this month', style: context.tt.labelLarge?.copyWith(color: muted)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        rangeLabel(s.start, s.end),
                        style: context.tt.labelSmall?.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedMoney(s.expense, style: context.tt.displaySmall?.copyWith(color: fg)),
                const SizedBox(height: 14),
                if (s.budget > 0) ...[
                  Bar(
                    value: s.budgetUsed,
                    height: 8,
                    color: over ? const Color(0xFFFFB4AB) : fg,
                    background: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    over
                        ? '${fmt.money(-s.budgetLeft)} over your ${fmt.money(s.budget)} budget'
                        : '${fmt.money(s.budgetLeft)} left of ${fmt.money(s.budget)} · ${pct(s.budgetUsed)} used',
                    style: context.tt.bodySmall?.copyWith(color: muted),
                  ),
                ] else
                  InkWell(
                    onTap: () => editMonthlyBudget(context),
                    child: Text('Set a monthly budget  →', style: context.tt.bodySmall?.copyWith(color: muted)),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _HeroStat(label: 'Income', value: s.income, icon: Icons.south_west_rounded),
                    _HeroStat(label: 'Saved', value: s.saved, icon: Icons.savings_rounded),
                    _HeroStat(label: 'Balance', value: s.balance, icon: Icons.account_balance_wallet_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.icon});
  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.72);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: 4),
            Text(label, style: context.tt.labelSmall?.copyWith(color: muted)),
          ]),
          const SizedBox(height: 4),
          AnimatedMoney(value, compact: true, style: context.tt.titleMedium?.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: context.cs.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This month has run $days days. Start a fresh one?',
                style: context.tt.bodyMedium?.copyWith(color: context.cs.onTertiaryContainer),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: context.cs.tertiary,
                foregroundColor: context.cs.onTertiary,
              ),
              onPressed: () => startNewCycleFlow(context),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCategories extends StatelessWidget {
  const _TopCategories({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    final top = stats.sortedCategories.take(5).toList();
    final maxV = top.first.value;
    return Pressable(
      onTap: () => Shell.goTo(context, 2),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              for (final e in top)
                Builder(builder: (context) {
                  final c = store.categoryById(e.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        CategoryAvatar.of(c, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(c.name, style: context.tt.bodyMedium, overflow: TextOverflow.ellipsis),
                                ),
                                Text(
                                  fmt.money(e.value),
                                  style: context.tt.labelLarge?.copyWith(fontFeatures: tabular),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Bar(value: e.value / maxV, color: c.colorValue, height: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 38,
                          child: Text(
                            pct(stats.expense == 0 ? 0 : e.value / stats.expense),
                            textAlign: TextAlign.end,
                            style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.r});
  final Recurring r;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = store.categoryById(r.categoryId);
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CategoryAvatar.of(c, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
                    Text(store.fmt.money(r.amount), style: context.tt.bodySmall?.copyWith(fontFeatures: tabular)),
                    Text(dayLabel(r.nextDue),
                        style: context.tt.labelSmall?.copyWith(color: context.cs.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
