import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// Create or edit a category. Returns the saved category.
Future<Category?> editCategory(BuildContext context, {Category? category, TxType type = TxType.expense}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CategorySheet(category: category, type: category?.type ?? type),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.category, required this.type});
  final Category? category;
  final TxType type;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late String _icon = widget.category?.icon ?? 'other';
  late int _color = widget.category?.color ?? kPalette[10];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final store = context.read<AppStore>();
    final c = widget.category;
    final saved = Category(
      id: c?.id ?? newId(),
      name: name,
      icon: _icon,
      color: _color,
      type: widget.type,
      budget: c?.budget,
    );
    store.upsertCategory(saved);
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.category == null ? 'New category' : 'Edit category', style: context.tt.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
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
                  autofocus: widget.category == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Name'),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('Tap the icon to change it',
                style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 16),
          ColorRow(colors: kPalette, selected: _color, onSelect: (c) => setState(() => _color = c)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  TxType _type = TxType.expense;

  Future<void> _delete(Category c) async {
    final store = context.read<AppStore>();
    final others = store.categoriesOf(c.type).where((x) => x.id != c.id).toList();
    if (others.isEmpty) {
      toast(context, 'Keep at least one category');
      return;
    }
    final used = store.usageCount(c.id);
    final fallback = others.firstWhere((x) => x.icon == 'other' || x.id.startsWith('other'), orElse: () => others.last);
    final ok = await confirm(
      context,
      title: 'Delete "${c.name}"?',
      message: used == 0
          ? 'This category has no transactions.'
          : '$used transaction${used == 1 ? '' : 's'} will move to "${fallback.name}".',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) store.deleteCategory(c, fallback.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cats = store.categoriesOf(_type);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => editCategory(context, type: _type),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('Expense')),
              ButtonSegment(value: TxType.income, label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final c in cats)
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    leading: CategoryAvatar.of(c, size: 40),
                    title: Text(c.name),
                    subtitle: Text('${store.usageCount(c.id)} transactions'),
                    onTap: () => editCategory(context, category: c),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _delete(c),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
