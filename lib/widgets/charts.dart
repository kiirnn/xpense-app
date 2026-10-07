import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

class DonutSlice {
  DonutSlice(this.category, this.value);
  final Category category;
  final double value;
}

class CategoryDonut extends StatefulWidget {
  const CategoryDonut({super.key, required this.slices, required this.centerLabel});

  final List<DonutSlice> slices;
  final String centerLabel;

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  int _touched = -1;

  @override
  void didUpdateWidget(covariant CategoryDonut old) {
    super.didUpdateWidget(old);
    if (_touched >= widget.slices.length) _touched = -1;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    final total = widget.slices.fold(0.0, (s, e) => s + e.value);
    final sel = _touched >= 0 ? widget.slices[_touched] : null;
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 72,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, resp) {
                  if (!event.isInterestedForInteractions || resp?.touchedSection == null) return;
                  final i = resp!.touchedSection!.touchedSectionIndex;
                  if (i != _touched) setState(() => _touched = i);
                },
              ),
              sections: [
                for (var i = 0; i < widget.slices.length; i++)
                  PieChartSectionData(
                    value: widget.slices[i].value,
                    color: widget.slices[i].category.colorValue.withValues(
                      alpha: _touched < 0 || _touched == i ? 1 : 0.35,
                    ),
                    radius: _touched == i ? 30 : 24,
                    showTitle: false,
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
          GestureDetector(
            onTap: () => setState(() => _touched = -1),
            child: SizedBox(
              width: 130,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey(_touched),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sel?.category.name ?? widget.centerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        fmt.money(sel?.value ?? total),
                        style: context.tt.titleLarge?.copyWith(fontFeatures: tabular),
                      ),
                    ),
                    if (sel != null && total > 0) Text(pct(sel.value / total), style: context.tt.labelMedium),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? _axis(BuildContext context) =>
    context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant, fontSize: 10);

BarTouchTooltipData _tooltip(BuildContext context, String Function(int group, int rod, double y) label) =>
    BarTouchTooltipData(
      getTooltipColor: (_) => context.cs.inverseSurface,
      tooltipBorderRadius: BorderRadius.circular(10),
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
        label(group.x, ri, rod.toY),
        context.tt.labelMedium!.copyWith(color: context.cs.onInverseSurface),
      ),
    );

/// One bar per day with a dashed line at the even daily budget. Shows one week
/// at a time (paged from the cycle start) or the whole cycle. Tapping anywhere
/// in a day's column pins its amount.
class DailyBars extends StatefulWidget {
  const DailyBars({super.key, required this.stats});

  final CycleStats stats;

  @override
  State<DailyBars> createState() => _DailyBarsState();
}

class _DailyBarsState extends State<DailyBars> {
  bool _weekly = true;
  late int _week;
  int? _selected;

  CycleStats get _s => widget.stats;
  int get _weeks => (_s.totalDays + 6) ~/ 7;

  @override
  void initState() {
    super.initState();
    _week = _initialWeek();
  }

  @override
  void didUpdateWidget(covariant DailyBars old) {
    super.didUpdateWidget(old);
    if (old.stats.cycle.id != _s.cycle.id) {
      _week = _initialWeek();
      _selected = null;
    } else if (_week >= _weeks) {
      _week = _weeks - 1;
    }
  }

  /// The week containing today, else the first week.
  int _initialWeek() {
    final i = dateOnly(DateTime.now()).difference(_s.start).inDays;
    return i >= 0 && i < _s.totalDays ? i ~/ 7 : 0;
  }

  void _setWeek(int w) => setState(() {
    _week = w;
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    final s = _s;
    final first = _weekly ? _week * 7 : 0;
    final days = _weekly ? min(7, s.totalDays - first) : s.totalDays;
    DateTime dayAt(int i) => s.start.add(Duration(days: first + i));
    final today = dateOnly(DateTime.now());
    final perDay = s.budget > 0 ? s.budget / s.totalDays : 0.0;
    final values = List.generate(days, (i) => s.byDay[dayAt(i)] ?? 0.0);
    final sum = values.fold(0.0, (a, v) => a + v);
    final maxY = max(values.fold(0.0, max), perDay) * 1.15;
    final top = maxY <= 0 ? 1.0 : maxY;
    final barW = _weekly ? 22.0 : (260 / days).clamp(3.0, 14.0);
    final dm = DateFormat('d MMM');
    final wd = DateFormat('EEE');
    final sel = _selected != null && _selected! < days ? _selected : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SegmentedButton<bool>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Week')),
                ButtonSegment(value: false, label: Text('Month')),
              ],
              selected: {_weekly},
              onSelectionChanged: (v) => setState(() {
                _weekly = v.first;
                _selected = null;
              }),
            ),
            const Spacer(),
            if (_weekly) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _week > 0 ? () => _setWeek(_week - 1) : null,
              ),
              Text('${dm.format(dayAt(0))} – ${dm.format(dayAt(days - 1))}', style: context.tt.labelMedium),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _week < _weeks - 1 ? () => _setWeek(_week + 1) : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          sel != null
              ? '${wd.format(dayAt(sel))}, ${dm.format(dayAt(sel))} · ${fmt.money(values[sel])}'
              : '${_weekly ? 'Week total' : 'Month total'} · ${fmt.money(sum)} · tap a day for its amount',
          style: context.tt.bodySmall?.copyWith(
            color: sel != null ? context.cs.onSurface : context.cs.onSurfaceVariant,
            fontWeight: sel != null ? FontWeight.w600 : null,
            fontFeatures: tabular,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: LayoutBuilder(
            builder: (context, box) {
              // Widen each bar's hit area to its whole column (half the gap on each side).
              final gap = days > 1 ? (box.maxWidth - days * barW) / (days - 1) : box.maxWidth;
              return BarChart(
                BarChartData(
                  maxY: top,
                  alignment: BarChartAlignment.spaceBetween,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (perDay > 0)
                        HorizontalLine(
                          y: perDay,
                          color: context.cs.tertiary.withValues(alpha: 0.7),
                          strokeWidth: 1.2,
                          dashArray: [4, 4],
                        ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _weekly ? 34 : 22,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          final d = dayAt(i);
                          final style = _axis(context)?.copyWith(
                            fontWeight: i == sel ? FontWeight.w800 : null,
                            color: i == sel ? context.cs.onSurface : null,
                          );
                          if (_weekly) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text('${wd.format(d)}\n${d.day}', textAlign: TextAlign.center, style: style),
                            );
                          }
                          final step = days > 20 ? 7 : (days > 10 ? 3 : 1);
                          if (i != sel) {
                            if (i % step != 0 && i != days - 1) return const SizedBox.shrink();
                            if (i == days - 1 && i % step != 0 && i % step < step / 2) return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(d.day.toString(), style: style),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    handleBuiltInTouches: false,
                    allowTouchBarBackDraw: true,
                    touchExtraThreshold: EdgeInsets.symmetric(horizontal: max(4.0, gap / 2)),
                    touchCallback: (event, resp) {
                      final i = resp?.spot?.touchedBarGroupIndex;
                      if (i == null) return;
                      if (event is FlTapUpEvent) {
                        setState(() => _selected = _selected == i ? null : i);
                      } else if (event is FlPanUpdateEvent || event is FlLongPressMoveUpdate) {
                        if (_selected != i) setState(() => _selected = i);
                      }
                    },
                  ),
                  barGroups: [
                    for (var i = 0; i < days; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i],
                            width: barW,
                            borderRadius: BorderRadius.circular(_weekly ? 8 : barW / 2),
                            color: dayAt(i).isAfter(today)
                                ? context.cs.surfaceContainerHighest
                                : (perDay > 0 && values[i] > perDay ? context.cs.tertiary : context.cs.primary)
                                      .withValues(alpha: sel == null || sel == i ? 1 : 0.4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: top,
                              color: i == sel
                                  ? context.cs.primary.withValues(alpha: 0.14)
                                  : context.cs.surfaceContainerHighest.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 300),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Income vs spending for the most recent cycles, oldest on the left.
class TrendBars extends StatelessWidget {
  const TrendBars({super.key, required this.cycles, this.selectedId});

  final List<CycleStats> cycles;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    final maxY = cycles.fold(0.0, (m, s) => max(m, max(s.income, s.expense))) * 1.15;
    final mon = DateFormat('MMM');
    String label(CycleStats s) => mon.format(s.start.add(Duration(days: s.end.difference(s.start).inDays ~/ 2)));

    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.cs.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(fmt.compact(v), style: _axis(context)),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final s = cycles[v.toInt()];
                  final sel = s.cycle.id == selectedId;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label(s),
                      style: _axis(
                        context,
                      )?.copyWith(fontWeight: sel ? FontWeight.w800 : null, color: sel ? context.cs.onSurface : null),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: _tooltip(context, (x, rod, y) => '${rod == 0 ? 'Income' : 'Spent'}\n${fmt.money(y)}'),
          ),
          barGroups: [
            for (var i = 0; i < cycles.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: cycles[i].income,
                    width: 12,
                    color: context.incomeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  BarChartRodData(
                    toY: cycles[i].expense,
                    width: 12,
                    color: context.cs.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }
}

/// Circular progress ring with a centered child.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.color, this.size = 56, this.stroke = 6, this.child});

  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
            if (child != null) Center(child: child),
          ],
        ),
        child: child,
      ),
    );
  }
}
