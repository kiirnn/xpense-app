import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../catalog.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.icon, required this.color, this.size = 44});

  CategoryAvatar.of(Category c, {super.key, this.size = 44})
      : icon = c.icon,
        color = c.colorValue;

  final String icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.13),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(iconFor(icon), color: color, size: size * 0.5),
    );
  }
}

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, this.onTap, this.showDate = false});

  final Txn txn;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = store.categoryById(txn.categoryId);
    final fmt = store.fmt;
    final subtitle = [
      if (showDate) dayLabel(txn.date),
      if (txn.note.isNotEmpty) c.name,
      txn.method,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CategoryAvatar.of(c),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          txn.note.isNotEmpty ? txn.note : c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall,
                        ),
                      ),
                      if (txn.recurringId != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.autorenew_rounded, size: 14, color: context.cs.onSurfaceVariant),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              fmt.signed(txn),
              style: context.tt.titleSmall?.copyWith(
                fontFeatures: tabular,
                color: txn.isExpense ? context.cs.onSurface : context.incomeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.tt.titleMedium)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: context.cs.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: context.cs.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title, style: context.tt.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Counts up to [value] whenever it changes.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.value, {super.key, this.style, this.compact = false});

  final double value;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<AppStore>().fmt;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        compact ? fmt.compact(v) : fmt.money(v == value ? v : v.roundToDouble()),
        style: (style ?? const TextStyle()).copyWith(fontFeatures: tabular),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color, this.height = 8, this.background});

  final double value;
  final Color? color;
  final Color? background;
  final double height;

  @override
  Widget build(BuildContext context) {
    final over = value > 1;
    final c = color ?? (over ? context.expenseColor : context.cs.primary);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: background ?? context.cs.surfaceContainerHighest,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle press-down scale used on tappable cards.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, required this.value, this.icon, this.color});

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color ?? context.cs.primary),
              const SizedBox(height: 10),
            ],
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.titleMedium?.copyWith(fontFeatures: tabular, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

void toast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.cs.error, foregroundColor: ctx.cs.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Bottom sheet with a single amount field. Returns null if dismissed.
Future<double?> askAmount(
  BuildContext context, {
  required String title,
  double? initial,
  String? hint,
  String confirmLabel = 'Save',
  bool allowClear = false,
}) {
  final store = context.read<AppStore>();
  final ctrl = TextEditingController(
    text: initial == null || initial == 0 ? '' : store.fmt.plain(initial).replaceAll(',', ''),
  );
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: ctx.tt.titleLarge),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: ctx.tt.bodyMedium?.copyWith(color: ctx.cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: ctx.tt.headlineSmall?.copyWith(fontFeatures: tabular),
            decoration: InputDecoration(prefixText: store.fmt.currency.symbol, hintText: '0'),
            onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (allowClear) ...[
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(ctx, 0.0), child: const Text('Remove')),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
