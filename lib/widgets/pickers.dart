import 'package:flutter/material.dart';

import '../catalog.dart';
import '../theme.dart';

Future<String?> pickCurrency(BuildContext context, String current) {
  return showModalBottomSheet<String>(
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
            child: Text('Currency', style: ctx.tt.titleLarge),
          ),
          for (final c in kCurrencies)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: ctx.cs.secondaryContainer,
                child: Text(c.symbol.trim(), style: TextStyle(color: ctx.cs.onSecondaryContainer, fontSize: 13)),
              ),
              title: Text(c.name),
              subtitle: Text(c.code),
              trailing: c.code == current ? Icon(Icons.check_circle_rounded, color: ctx.cs.primary) : null,
              onTap: () => Navigator.pop(ctx, c.code),
            ),
        ],
      ),
    ),
  );
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial, {DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: last ?? DateTime(2100),
  );
}

/// Grid of icon keys from the catalog.
Future<String?> pickIcon(BuildContext context, String current, Color color) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => GridView.count(
        controller: scroll,
        crossAxisCount: 6,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final e in kIcons.entries)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(ctx, e.key),
              child: Container(
                decoration: BoxDecoration(
                  color: e.key == current ? color.withValues(alpha: 0.2) : ctx.cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: e.key == current ? Border.all(color: color, width: 2) : null,
                ),
                child: Icon(e.value, color: e.key == current ? color : ctx.cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    ),
  );
}

class ColorRow extends StatelessWidget {
  const ColorRow({super.key, required this.colors, required this.selected, required this.onSelect});

  final List<int> colors;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected ? context.cs.onSurface : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: c == selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
            ),
          ),
      ],
    );
  }
}
