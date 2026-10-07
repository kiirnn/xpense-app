import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/pickers.dart';

/// Closes the current month and opens a new one, with undo.
Future<void> startNewCycleFlow(BuildContext context) async {
  final store = context.read<AppStore>();
  final messenger = ScaffoldMessenger.of(context);
  final started = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _NewCycleSheet(),
  );
  if (started != true) return;
  HapticFeedback.heavyImpact();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text('New month started · ${cycleName(store.current.start, store.current.end)}'),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(label: 'Undo', onPressed: store.undoLastReset),
  ));
}

class _NewCycleSheet extends StatefulWidget {
  const _NewCycleSheet();

  @override
  State<_NewCycleSheet> createState() => _NewCycleSheetState();
}

class _NewCycleSheetState extends State<_NewCycleSheet> {
  late DateTime _start;
  late final TextEditingController _budget;
  late bool _carry;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final today = dateOnly(DateTime.now());
    final earliest = store.activeCycle.start.add(const Duration(days: 1));
    _start = today.isBefore(earliest) ? earliest : today;
    final b = store.activeCycle.budget;
    _budget = TextEditingController(text: b > 0 ? b.toStringAsFixed(b % 1 == 0 ? 0 : 2) : '');
    _carry = store.settings.carryOver;
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = store.fmt;
    final cur = store.current;
    final earliest = store.activeCycle.start.add(const Duration(days: 1));
    final today = dateOnly(DateTime.now());

    // Preview of the closing month as it will be once the new one begins.
    final closing = cur.txns.where((t) => dateOnly(t.date).isBefore(_start));
    final spent = closing.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final earned = closing.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final balance = store.activeCycle.openingBalance + earned - spent;
    final moving = cur.txns.length - closing.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start a new month', style: context.tt.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${cycleName(cur.start, _start.subtract(const Duration(days: 1)))} will be saved to your month logs.',
              style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                _Mini(label: 'Spent', value: fmt.money(spent)),
                _Mini(label: 'Earned', value: fmt.money(earned)),
                _Mini(
                  label: 'Saved',
                  value: fmt.money(earned - spent),
                  color: earned - spent >= 0 ? context.incomeColor : context.expenseColor,
                ),
              ]),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: context.theme.inputDecorationTheme.fillColor,
              leading: const Icon(Icons.event_rounded),
              title: Text('New month starts ${dayLabel(_start).toLowerCase() == 'today' ? 'today' : 'on ${longDate(_start)}'}'),
              subtitle: moving > 0 ? Text('$moving transaction${moving == 1 ? '' : 's'} from this date will move to the new month') : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final d = await pickDate(
                  context,
                  _start,
                  first: earliest,
                  last: today.isBefore(earliest) ? earliest : today,
                );
                if (d != null) setState(() => _start = dateOnly(d));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Budget for the new month',
                prefixText: fmt.currency.symbol,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: _carry,
              onChanged: (v) => setState(() => _carry = v),
              title: const Text('Carry balance forward'),
              subtitle: Text('Start with ${fmt.money(_carry ? balance : 0)} opening balance'),
            ),
            const SizedBox(height: 4),
            Text(
              'Category budgets, goals and recurring items continue as they are.',
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () {
                store.startNewCycle(
                  start: _start,
                  budget: double.tryParse(_budget.text) ?? 0,
                  carryOver: _carry,
                );
                Navigator.pop(context, true);
              },
              label: const Text('Start new month'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.tt.titleMedium?.copyWith(color: color, fontFeatures: tabular)),
          ),
        ]),
      );
}
