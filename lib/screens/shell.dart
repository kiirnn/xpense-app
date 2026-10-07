import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'activity.dart';
import 'history.dart';
import 'home.dart';
import 'insights.dart';
import 'plan.dart';
import 'txn_editor.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  static void goTo(BuildContext context, int tab) =>
      context.findAncestorStateOfType<_ShellState>()?._select(tab);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _pages = [HomeScreen(), ActivityScreen(), InsightsScreen(), PlanScreen(), HistoryScreen()];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        floatingActionButton: _index <= 2
            ? FloatingActionButton.extended(
                heroTag: 'add',
                onPressed: () => openTxnEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
            NavigationDestination(icon: Icon(Icons.donut_large_outlined), selectedIcon: Icon(Icons.donut_large_rounded), label: 'Insights'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag_rounded), label: 'Plan'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Months'),
          ],
        ),
      ),
    );
  }
}
