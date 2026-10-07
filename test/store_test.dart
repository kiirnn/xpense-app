import 'package:flutter_test/flutter_test.dart';
import 'package:xpense/catalog.dart';
import 'package:xpense/format.dart';
import 'package:xpense/models.dart';
import 'package:xpense/store.dart';

Txn tx(double amount, DateTime date, {TxType type = TxType.expense, String cat = 'food'}) =>
    Txn(id: newId(), type: type, amount: amount, categoryId: cat, date: date);

AppStore storeFrom(DateTime start, {double budget = 1000}) {
  final s = AppStore()..categories = defaultCategories();
  s.cycles.add(Cycle(id: 'c1', start: start, budget: budget));
  return s;
}

void main() {
  test('addMonth clamps to month length', () {
    expect(addMonth(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    expect(addMonth(DateTime(2026, 2, 28), 1, 31), DateTime(2026, 3, 31));
    expect(addMonth(DateTime(2026, 12, 15)), DateTime(2027, 1, 15));
  });

  test('stats, reset with carry-over, and undo', () {
    final today = dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 20));
    final s = storeFrom(start);
    s.txns.addAll([
      tx(5000, start, type: TxType.income, cat: 'salary'),
      tx(300, start.add(const Duration(days: 1))),
      tx(200, today),
    ]);

    expect(s.current.expense, 500);
    expect(s.current.income, 5000);
    expect(s.current.balance, 4500);

    s.startNewCycle(start: today, budget: 2000, carryOver: true);
    expect(s.cycles.length, 2);
    final prev = s.stats(s.cycles.first);
    expect(prev.expense, 300, reason: 'today\'s txn moves to the new month');
    expect(prev.isActive, isFalse);
    expect(prev.end, today.subtract(const Duration(days: 1)));
    expect(s.current.expense, 200);
    expect(s.activeCycle.openingBalance, 4700);
    expect(s.current.balance, 4500);
    expect(s.current.budget, 2000);

    s.undoLastReset();
    expect(s.cycles.length, 1);
    expect(s.current.expense, 500);
  });

  test('recurring posts due items and advances monthly', () {
    final today = dateOnly(DateTime.now());
    final s = storeFrom(today.subtract(const Duration(days: 70)));
    final first = addMonth(today, -2);
    s.recurring.add(Recurring(
      id: 'r1',
      type: TxType.expense,
      amount: 499,
      categoryId: 'subscriptions',
      name: 'Netflix',
      dayOfMonth: first.day,
      nextDue: first,
    ));
    final added = s.processRecurring(save: false);
    expect(added, 3);
    expect(s.txns.where((t) => t.recurringId == 'r1').length, 3);
    expect(s.recurring.first.nextDue.isAfter(today), isTrue);
    expect(s.processRecurring(save: false), 0);
  });

  test('backup round-trips', () {
    final s = storeFrom(DateTime(2026, 9, 1));
    s.txns.add(tx(42.5, DateTime(2026, 9, 3)));
    s.goals.add(Goal(id: 'g', name: 'Trip', target: 10000, saved: 2500, icon: 'travel', color: 0xFF000000));
    final json = s.exportJson();

    final t = AppStore()..importJson(json);
    expect(t.txns.single.amount, 42.5);
    expect(t.goals.single.saved, 2500);
    expect(t.cycles.single.start, DateTime(2026, 9, 1));
    expect(() => t.importJson('{"foo": 1}'), throwsFormatException);
  });

  test('csv escapes quotes', () {
    final s = storeFrom(DateTime(2026, 9, 1));
    s.txns.add(Txn(id: 'x', type: TxType.expense, amount: 10, categoryId: 'food', date: DateTime(2026, 9, 2), note: 'say "hi"'));
    expect(s.exportCsv(), contains('"say ""hi"""'));
  });
}
