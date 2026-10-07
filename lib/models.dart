import 'package:flutter/material.dart';

enum TxType { expense, income }

TxType _type(Object? v) => v == 'income' ? TxType.income : TxType.expense;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _date(Object? v) => DateTime.parse(v as String);

class Category {
  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.budget,
  });

  final String id;
  String name;
  String icon;
  int color;
  TxType type;

  /// Optional monthly limit for this category (expense categories only).
  double? budget;

  Color get colorValue => Color(color);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'type': type.name,
        if (budget != null) 'budget': budget,
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        icon: j['icon'] ?? 'other',
        color: j['color'],
        type: _type(j['type']),
        budget: (j['budget'] as num?)?.toDouble(),
      );
}

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note = '',
    this.method = 'UPI',
    this.recurringId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  TxType type;
  double amount;
  String categoryId;
  DateTime date;
  String note;
  String method;
  String? recurringId;
  final DateTime createdAt;

  bool get isExpense => type == TxType.expense;
  double get signed => isExpense ? -amount : amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'date': date.toIso8601String(),
        'note': note,
        'method': method,
        if (recurringId != null) 'recurringId': recurringId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'],
        type: _type(j['type']),
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'],
        date: _date(j['date']),
        note: j['note'] ?? '',
        method: j['method'] ?? 'Other',
        recurringId: j['recurringId'],
        createdAt: j['createdAt'] != null ? _date(j['createdAt']) : null,
      );
}

/// A tracking period. Cycles are contiguous: a cycle runs from its [start]
/// until the day before the next cycle's start. The last one is the active cycle.
class Cycle {
  Cycle({
    required this.id,
    required this.start,
    required this.budget,
    this.openingBalance = 0,
  });

  final String id;
  DateTime start;
  double budget;

  /// Balance carried over from the previous cycle.
  double openingBalance;

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'budget': budget,
        'openingBalance': openingBalance,
      };

  factory Cycle.fromJson(Map<String, dynamic> j) => Cycle(
        id: j['id'],
        start: _date(j['start']),
        budget: (j['budget'] as num).toDouble(),
        openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
      );
}

class Recurring {
  Recurring({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.name,
    required this.dayOfMonth,
    required this.nextDue,
    this.method = 'UPI',
    this.active = true,
  });

  final String id;
  TxType type;
  double amount;
  String categoryId;
  String name;
  int dayOfMonth;
  DateTime nextDue;
  String method;
  bool active;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'name': name,
        'dayOfMonth': dayOfMonth,
        'nextDue': nextDue.toIso8601String(),
        'method': method,
        'active': active,
      };

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'],
        type: _type(j['type']),
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'],
        name: j['name'] ?? '',
        dayOfMonth: j['dayOfMonth'] ?? 1,
        nextDue: _date(j['nextDue']),
        method: j['method'] ?? 'UPI',
        active: j['active'] ?? true,
      );
}

class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.target,
    required this.icon,
    required this.color,
    this.saved = 0,
    this.deadline,
  });

  final String id;
  String name;
  double target;
  double saved;
  String icon;
  int color;
  DateTime? deadline;

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1).toDouble();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'icon': icon,
        'color': color,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'],
        name: j['name'],
        target: (j['target'] as num).toDouble(),
        saved: (j['saved'] as num?)?.toDouble() ?? 0,
        icon: j['icon'] ?? 'savings',
        color: j['color'],
        deadline: j['deadline'] != null ? _date(j['deadline']) : null,
      );
}

class Settings {
  Settings({
    this.name = '',
    this.currencyCode = 'INR',
    this.themeMode = ThemeMode.system,
    this.accent = 0xFF4F46E5,
    this.lockEnabled = false,
    this.hideAmounts = false,
    this.onboarded = false,
    this.carryOver = true,
  });

  String name;
  String currencyCode;
  ThemeMode themeMode;
  int accent;
  bool lockEnabled;
  bool hideAmounts;
  bool onboarded;

  /// Default for "carry leftover balance into the next month".
  bool carryOver;

  Map<String, dynamic> toJson() => {
        'name': name,
        'currencyCode': currencyCode,
        'themeMode': themeMode.name,
        'accent': accent,
        'lockEnabled': lockEnabled,
        'hideAmounts': hideAmounts,
        'onboarded': onboarded,
        'carryOver': carryOver,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        name: j['name'] ?? '',
        currencyCode: j['currencyCode'] ?? 'INR',
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        accent: j['accent'] ?? 0xFF4F46E5,
        lockEnabled: j['lockEnabled'] ?? false,
        hideAmounts: j['hideAmounts'] ?? false,
        onboarded: j['onboarded'] ?? false,
        carryOver: j['carryOver'] ?? true,
      );
}

/// Aggregated numbers for one cycle.
class CycleStats {
  CycleStats({
    required this.cycle,
    required this.start,
    required this.end,
    required this.isActive,
    required this.txns,
  }) {
    for (final t in txns) {
      if (t.isExpense) {
        expense += t.amount;
        byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amount;
        final d = dateOnly(t.date);
        byDay[d] = (byDay[d] ?? 0) + t.amount;
        byMethod[t.method] = (byMethod[t.method] ?? 0) + t.amount;
        if (biggest == null || t.amount > biggest!.amount) biggest = t;
      } else {
        income += t.amount;
        incomeByCategory[t.categoryId] = (incomeByCategory[t.categoryId] ?? 0) + t.amount;
      }
    }
  }

  final Cycle cycle;
  final DateTime start;

  /// Inclusive last day. For the active cycle this is the projected end.
  final DateTime end;
  final bool isActive;
  final List<Txn> txns;

  double income = 0;
  double expense = 0;
  final Map<String, double> byCategory = {};
  final Map<String, double> incomeByCategory = {};
  final Map<DateTime, double> byDay = {};
  final Map<String, double> byMethod = {};
  Txn? biggest;

  double get budget => cycle.budget;
  double get saved => income - expense;
  double get balance => cycle.openingBalance + income - expense;
  double get savingsRate => income <= 0 ? 0 : saved / income;
  double get budgetUsed => budget <= 0 ? 0 : expense / budget;
  double get budgetLeft => budget - expense;

  int get totalDays => end.difference(start).inDays + 1;

  int get elapsedDays {
    if (!isActive) return totalDays;
    final today = dateOnly(DateTime.now());
    return (today.difference(start).inDays + 1).clamp(1, 100000);
  }

  int get daysLeft {
    if (!isActive) return 0;
    final today = dateOnly(DateTime.now());
    return (end.difference(today).inDays + 1).clamp(0, 100000);
  }

  double get dailyAverage => expense / elapsedDays;

  /// How much can still be spent per day for the rest of the cycle.
  double get safeDaily => daysLeft <= 0 ? 0 : (budgetLeft / daysLeft).clamp(0, double.infinity);

  /// Expected total spend at current pace.
  double get projected => isActive ? dailyAverage * totalDays : expense;

  List<MapEntry<String, double>> get sortedCategories =>
      byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
