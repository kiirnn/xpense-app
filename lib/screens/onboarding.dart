import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../catalog.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/pickers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  String _currency = 'INR';
  DateTime _start = dateOnly(DateTime.now());

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    context.read<AppStore>().completeOnboarding(
          name: _name.text,
          currency: _currency,
          start: _start,
          budget: double.tryParse(_budget.text) ?? 0,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cur = currencyFor(_currency);
    final firstOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.cs.primary, context.cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.account_balance_wallet_rounded, color: context.cs.onPrimary, size: 32),
            ),
            const SizedBox(height: 28),
            Text('Welcome to Xpense', style: context.tt.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'A private, offline money tracker. Everything stays on this device.',
              style: context.tt.bodyLarge?.copyWith(color: context.cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            _Label('What should we call you?'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your name'),
            ),
            const SizedBox(height: 20),
            _Label('Currency'),
            _Tile(
              icon: Icons.currency_exchange_rounded,
              title: '${cur.name} (${cur.symbol.trim()})',
              onTap: () async {
                final c = await pickCurrency(context, _currency);
                if (c != null) setState(() => _currency = c);
              },
            ),
            const SizedBox(height: 20),
            _Label('Your month starts on'),
            _Tile(
              icon: Icons.event_rounded,
              title: longDate(_start),
              onTap: () async {
                final d = await pickDate(context, _start, last: DateTime.now());
                if (d != null) setState(() => _start = dateOnly(d));
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _start == dateOnly(DateTime.now()),
                  onSelected: (_) => setState(() => _start = dateOnly(DateTime.now())),
                ),
                ChoiceChip(
                  label: Text('1st ${shortDate(firstOfMonth).split(' ').last}'),
                  selected: _start == firstOfMonth,
                  onSelected: (_) => setState(() => _start = firstOfMonth),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Use your salary day. You can start a new month any time from the Months tab.',
                style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            _Label('Monthly spending budget'),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(prefixText: cur.symbol, hintText: 'Optional'),
            ),
            const SizedBox(height: 36),
            FilledButton(onPressed: _finish, child: const Text('Get started')),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: context.cs.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: context.tt.bodyLarge)),
                Icon(Icons.chevron_right_rounded, color: context.cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
}
