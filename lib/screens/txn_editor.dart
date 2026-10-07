import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../catalog.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'categories.dart';

Future<void> openTxnEditor(BuildContext context, {Txn? txn, TxType type = TxType.expense}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TxnEditor(txn: txn, initialType: type),
    ),
  );
}

/// Deletes with an undo snackbar.
void deleteTxnWithUndo(BuildContext context, Txn t) {
  final store = context.read<AppStore>();
  final messenger = ScaffoldMessenger.of(context);
  store.deleteTxn(t);
  HapticFeedback.mediumImpact();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Transaction deleted'),
      action: SnackBarAction(label: 'Undo', onPressed: () => store.upsertTxn(t)),
    ),
  );
}

class TxnEditor extends StatefulWidget {
  const TxnEditor({super.key, this.txn, this.initialType = TxType.expense});

  final Txn? txn;
  final TxType initialType;

  @override
  State<TxnEditor> createState() => _TxnEditorState();
}

class _TxnEditorState extends State<TxnEditor> {
  late TxType _type;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  final _amountFocus = FocusNode();
  String? _categoryId;
  late DateTime _date;
  late String _method;
  bool _categoryTouched = false;

  bool get _editing => widget.txn != null;

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    final store = context.read<AppStore>();
    _type = t?.type ?? widget.initialType;
    _amount = TextEditingController(text: t == null ? '' : _plain(t.amount));
    _note = TextEditingController(text: t?.note ?? '');
    _categoryId = t?.categoryId;
    _date = t?.date ?? DateTime.now();
    _method = t?.method ?? _lastMethod(store);
    _note.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
  }

  String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  String _lastMethod(AppStore store) {
    final s = store.txnsSorted;
    return s.isEmpty ? 'UPI' : s.first.method;
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text) ?? 0;

  bool get _valid => _value > 0 && _categoryId != null;

  void _save() {
    if (!_valid) {
      HapticFeedback.heavyImpact();
      toast(context, _value <= 0 ? 'Enter an amount' : 'Pick a category');
      return;
    }
    final store = context.read<AppStore>();
    final now = DateTime.now();
    // Keep the time of day for ordering within a day.
    final date = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute, now.second);
    final old = widget.txn;
    store.upsertTxn(
      Txn(
        id: old?.id ?? newId(),
        type: _type,
        amount: _value,
        categoryId: _categoryId!,
        date: old != null && dateOnly(old.date) == dateOnly(_date) ? old.date : date,
        note: _note.text.trim(),
        method: _method,
        recurringId: old?.recurringId,
        createdAt: old?.createdAt,
      ),
    );
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete transaction?',
      message: 'You can undo this right after.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    deleteTxnWithUndo(context, widget.txn!);
    Navigator.pop(context);
  }

  void _setType(TxType t) {
    if (t == _type) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = t;
      _categoryId = null;
      _categoryTouched = false;
    });
  }

  /// Focuses the amount field from a tap anywhere on its row, cursor at the end.
  void _focusAmount() {
    if (_amountFocus.hasFocus) {
      // Still focused but the keyboard was dismissed (e.g. via back): reopen it.
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } else {
      _amountFocus.requestFocus();
    }
    _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
  }

  void _pickSuggestion(String s) {
    final store = context.read<AppStore>();
    _note.text = s;
    _note.selection = TextSelection.collapsed(offset: s.length);
    if (!_categoryTouched) {
      final c = store.categoryForNote(s, _type);
      if (c != null) setState(() => _categoryId = c);
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cats = store.categoriesOf(_type);
    final accent = _type == TxType.expense ? context.cs.primary : context.incomeColor;
    final q = _note.text.trim().toLowerCase();
    final suggestions = store
        .noteSuggestions(_type)
        .where((s) => s.toLowerCase() != q && (q.isEmpty || s.toLowerCase().contains(q)))
        .take(8)
        .toList();
    final today = dateOnly(DateTime.now());
    final d = dateOnly(_date);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(_editing ? 'Edit transaction' : 'New transaction'),
        actions: [
          if (_editing) IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
              ButtonSegment(value: TxType.income, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => _setType(s.first),
          ),
          const SizedBox(height: 16),
          // The whole row is tappable, not just the narrow field itself.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusAmount,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: IntrinsicWidth(
                  child: TextField(
                    controller: _amount,
                    focusNode: _amountFocus,
                    autofocus: !_editing,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?'))],
                    style: context.tt.displaySmall?.copyWith(fontFeatures: tabular, color: accent),
                    cursorColor: accent,
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: '0',
                      hintStyle: context.tt.displaySmall?.copyWith(color: context.cs.outlineVariant),
                      prefixText: store.fmt.currency.symbol,
                      prefixStyle: context.tt.headlineMedium?.copyWith(color: accent.withValues(alpha: 0.7)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _type == TxType.expense ? 'What was it for?' : 'Source (e.g. October salary)',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          if (suggestions.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 8),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(suggestions[i]),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _pickSuggestion(suggestions[i]),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Category', style: context.tt.titleSmall),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: cats.length + 1,
            itemBuilder: (_, i) {
              if (i == cats.length) {
                return _CategoryCell(
                  label: 'New',
                  selected: false,
                  overrideIcon: Icons.add_rounded,
                  onTap: () async {
                    final c = await editCategory(context, type: _type);
                    if (c != null) setState(() => _categoryId = c.id);
                  },
                  child: const SizedBox.shrink(),
                );
              }
              final c = cats[i];
              return _CategoryCell(
                label: c.name,
                selected: c.id == _categoryId,
                color: c.colorValue,
                child: CategoryAvatar.of(c),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _categoryId = c.id;
                    _categoryTouched = true;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Date', style: context.tt.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Today'),
                selected: d == today,
                onSelected: (_) => setState(() => _date = DateTime.now()),
              ),
              ChoiceChip(
                label: const Text('Yesterday'),
                selected: d == today.subtract(const Duration(days: 1)),
                onSelected: (_) => setState(() => _date = today.subtract(const Duration(days: 1))),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.event_rounded, size: 18),
                label: Text(d == today || d == today.subtract(const Duration(days: 1)) ? 'Pick date' : longDate(d)),
                selected: d != today && d != today.subtract(const Duration(days: 1)),
                onSelected: (_) async {
                  final p = await pickDate(context, _date, last: today.add(const Duration(days: 365)));
                  if (p != null) setState(() => _date = p);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(_type == TxType.expense ? 'Paid with' : 'Received via', style: context.tt.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in kMethods)
                ChoiceChip(
                  avatar: Icon(methodIcon(m), size: 18),
                  label: Text(m),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: AnimatedOpacity(
            opacity: _valid ? 1 : 0.6,
            duration: const Duration(milliseconds: 200),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
              onPressed: _save,
              child: Text(_editing ? 'Save changes' : 'Add ${_type == TxType.expense ? 'expense' : 'income'}'),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
    this.color,
    this.overrideIcon,
  });

  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;
  final Color? color;
  final IconData? overrideIcon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cs.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? c.withValues(alpha: 0.14) : Colors.transparent,
          border: Border.all(color: selected ? c : Colors.transparent, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            overrideIcon != null
                ? Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: context.cs.outlineVariant),
                    ),
                    child: Icon(overrideIcon, color: context.cs.onSurfaceVariant),
                  )
                : child,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.tt.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? context.cs.onSurface : context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
