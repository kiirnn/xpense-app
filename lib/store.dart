import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'format.dart';
import 'models.dart';

final _rand = Random();

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) + _rand.nextInt(1 << 20).toRadixString(36);

class AppStore extends ChangeNotifier {
  static const _fileName = 'xpense_data.json';
  static const schemaVersion = 1;

  Settings settings = Settings();
  List<Category> categories = [];
  List<Txn> txns = [];
  List<Cycle> cycles = [];
  List<Recurring> recurring = [];
  List<Goal> goals = [];

  bool loaded = false;
  File? _file;
  Future<void> _pendingWrite = Future.value();
  final Map<String, CycleStats> _statsCache = {};

  // ---------------------------------------------------------------- persistence

  Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    try {
      if (await _file!.exists()) {
        _apply(jsonDecode(await _file!.readAsString()) as Map<String, dynamic>);
      } else {
        categories = defaultCategories();
      }
    } catch (_) {
      // Main file is unreadable: fall back to the last good backup.
      final bak = File('${_file!.path}.bak');
      if (await bak.exists()) {
        _apply(jsonDecode(await bak.readAsString()) as Map<String, dynamic>);
      } else {
        categories = defaultCategories();
      }
    }
    loaded = true;
    processRecurring(save: false);
    notifyListeners();
  }

  void _apply(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    settings = Settings.fromJson(Map<String, dynamic>.from((j['settings'] as Map?) ?? {}));
    categories = list('categories', Category.fromJson);
    txns = list('txns', Txn.fromJson);
    cycles = list('cycles', Cycle.fromJson)..sort((a, b) => a.start.compareTo(b.start));
    recurring = list('recurring', Recurring.fromJson);
    goals = list('goals', Goal.fromJson);
    if (categories.isEmpty) categories = defaultCategories();
    _statsCache.clear();
  }

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'txns': txns.map((e) => e.toJson()).toList(),
        'cycles': cycles.map((e) => e.toJson()).toList(),
        'recurring': recurring.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
      };

  /// Writes are serialized and atomic (temp file + rename), with one rolling backup.
  void _save() {
    final file = _file;
    if (file == null) return;
    final data = jsonEncode(toJson());
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(data, flush: true);
        if (await file.exists()) await file.copy('${file.path}.bak');
        await tmp.rename(file.path);
      } catch (e) {
        debugPrint('Save failed: $e');
      }
    });
  }

  void _changed() {
    _statsCache.clear();
    _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------ settings

  Fmt get fmt => Fmt(settings.currencyCode, hidden: settings.hideAmounts);

  void updateSettings(void Function(Settings s) f) {
    f(settings);
    _changed();
  }

  void completeOnboarding({
    required String name,
    required String currency,
    required DateTime start,
    required double budget,
  }) {
    settings
      ..name = name.trim()
      ..currencyCode = currency
      ..onboarded = true;
    if (cycles.isEmpty) {
      cycles.add(Cycle(id: newId(), start: dateOnly(start), budget: budget));
    }
    _changed();
  }

  // ------------------------------------------------------------------ categories

  Category categoryById(String id) => categories.firstWhere(
        (c) => c.id == id,
        orElse: () => Category(id: id, name: 'Uncategorized', icon: 'other', color: 0xFF94A3B8, type: TxType.expense),
      );

  List<Category> categoriesOf(TxType type) => categories.where((c) => c.type == type).toList();

  void upsertCategory(Category c) {
    final i = categories.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      categories[i] = c;
    } else {
      categories.add(c);
    }
    _changed();
  }

  /// Moves this category's transactions to [moveTo] before deleting it.
  void deleteCategory(Category c, String moveTo) {
    for (final t in txns.where((t) => t.categoryId == c.id)) {
      t.categoryId = moveTo;
    }
    for (final r in recurring.where((r) => r.categoryId == c.id)) {
      r.categoryId = moveTo;
    }
    categories.removeWhere((x) => x.id == c.id);
    _changed();
  }

  void setCategoryBudget(String id, double? budget) {
    categoryById(id).budget = (budget == null || budget <= 0) ? null : budget;
    _changed();
  }

  int usageCount(String categoryId) => txns.where((t) => t.categoryId == categoryId).length;

  // ------------------------------------------------------------------ transactions

  void upsertTxn(Txn t) {
    final i = txns.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      txns[i] = t;
    } else {
      txns.add(t);
    }
    _changed();
  }

  void deleteTxn(Txn t) {
    txns.removeWhere((x) => x.id == t.id);
    _changed();
  }

  List<Txn> get txnsSorted => [...txns]..sort(_byDateDesc);

  static int _byDateDesc(Txn a, Txn b) {
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
  }

  /// Distinct notes used before, most frequent first, for autocomplete.
  List<String> noteSuggestions(TxType type) {
    final counts = <String, int>{};
    for (final t in txns.where((t) => t.type == type && t.note.trim().isNotEmpty)) {
      counts[t.note.trim()] = (counts[t.note.trim()] ?? 0) + 1;
    }
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList();
  }

  /// Category most recently used with this note, to auto-pick it in the editor.
  String? categoryForNote(String note, TxType type) {
    final n = note.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final t in txnsSorted) {
      if (t.type == type && t.note.trim().toLowerCase() == n) return t.categoryId;
    }
    return null;
  }

  // ------------------------------------------------------------------ cycles

  Cycle get activeCycle => cycles.last;
  bool get hasCycle => cycles.isNotEmpty;

  /// Cycles newest first.
  List<Cycle> get cyclesDesc => cycles.reversed.toList();

  DateTime projectedEnd(Cycle c) => addMonth(c.start).subtract(const Duration(days: 1));

  /// True once the active cycle has run past a full month: time to reset.
  bool get cycleOverdue =>
      hasCycle && dateOnly(DateTime.now()).isAfter(projectedEnd(activeCycle));

  int get activeCycleAgeDays => dateOnly(DateTime.now()).difference(activeCycle.start).inDays + 1;

  CycleStats stats(Cycle c) => _statsCache.putIfAbsent(c.id, () {
        final i = cycles.indexOf(c);
        final isActive = i == cycles.length - 1;
        final nextStart = isActive ? null : cycles[i + 1].start;
        DateTime end;
        if (isActive) {
          end = projectedEnd(c);
          final today = dateOnly(DateTime.now());
          if (today.isAfter(end)) end = today;
        } else {
          end = nextStart!.subtract(const Duration(days: 1));
        }
        final list = txns.where((t) {
          final d = dateOnly(t.date);
          if (i > 0 && d.isBefore(c.start)) return false;
          if (nextStart != null && !d.isBefore(nextStart)) return false;
          return true;
        }).toList()
          ..sort(_byDateDesc);
        return CycleStats(cycle: c, start: c.start, end: end, isActive: isActive, txns: list);
      });

  CycleStats get current => stats(activeCycle);

  CycleStats? previousOf(Cycle c) {
    final i = cycles.indexOf(c);
    return i > 0 ? stats(cycles[i - 1]) : null;
  }

  Cycle cycleForDate(DateTime d) {
    final x = dateOnly(d);
    for (final c in cyclesDesc) {
      if (!x.isBefore(c.start)) return c;
    }
    return cycles.first;
  }

  /// Closes the active cycle the day before [start] and opens a new one.
  void startNewCycle({required DateTime start, required double budget, required bool carryOver}) {
    final s = dateOnly(start);
    final prev = activeCycle;
    final next = Cycle(id: newId(), start: s, budget: budget);
    cycles.add(next);
    _statsCache.clear();
    if (carryOver) next.openingBalance = stats(prev).balance;
    settings.carryOver = carryOver;
    _changed();
  }

  /// Merges the active cycle back into the previous one.
  void undoLastReset() {
    if (cycles.length < 2) return;
    cycles.removeLast();
    _changed();
  }

  void updateCycle(Cycle c, {double? budget, DateTime? start}) {
    if (budget != null) c.budget = budget;
    if (start != null) c.start = dateOnly(start);
    cycles.sort((a, b) => a.start.compareTo(b.start));
    _changed();
  }

  // ------------------------------------------------------------------ recurring

  void upsertRecurring(Recurring r) {
    final i = recurring.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      recurring[i] = r;
    } else {
      recurring.add(r);
    }
    processRecurring(save: false);
    _changed();
  }

  void deleteRecurring(Recurring r) {
    recurring.removeWhere((x) => x.id == r.id);
    _changed();
  }

  /// Posts every due occurrence up to today. Returns how many were added.
  int processRecurring({bool save = true}) {
    final today = dateOnly(DateTime.now());
    var added = 0;
    for (final r in recurring.where((r) => r.active)) {
      var guard = 0;
      while (!dateOnly(r.nextDue).isAfter(today) && guard++ < 36) {
        txns.add(Txn(
          id: newId(),
          type: r.type,
          amount: r.amount,
          categoryId: r.categoryId,
          date: r.nextDue,
          note: r.name,
          method: r.method,
          recurringId: r.id,
        ));
        r.nextDue = addMonth(r.nextDue, 1, r.dayOfMonth);
        added++;
      }
    }
    if (added > 0) {
      if (save) {
        _changed();
      } else {
        _statsCache.clear();
        _save();
      }
    }
    return added;
  }

  List<Recurring> upcoming({int days = 7}) {
    final limit = dateOnly(DateTime.now()).add(Duration(days: days));
    return recurring.where((r) => r.active && !r.nextDue.isAfter(limit)).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  }

  double get monthlyRecurringExpense =>
      recurring.where((r) => r.active && r.type == TxType.expense).fold(0.0, (s, r) => s + r.amount);

  // ------------------------------------------------------------------ goals

  void upsertGoal(Goal g) {
    final i = goals.indexWhere((x) => x.id == g.id);
    if (i >= 0) {
      goals[i] = g;
    } else {
      goals.add(g);
    }
    _changed();
  }

  void adjustGoal(Goal g, double delta) {
    g.saved = max(0, g.saved + delta);
    _changed();
  }

  void deleteGoal(Goal g) {
    goals.removeWhere((x) => x.id == g.id);
    _changed();
  }

  // ------------------------------------------------------------------ backup

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Throws [FormatException] if the content is not an Xpense backup.
  void importJson(String content) {
    final j = jsonDecode(content);
    if (j is! Map || j['version'] == null || j['txns'] is! List || j['cycles'] is! List) {
      throw const FormatException('Not an Xpense backup file');
    }
    _apply(Map<String, dynamic>.from(j));
    settings.onboarded = cycles.isNotEmpty;
    _changed();
  }

  String exportCsv() {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Date,Type,Category,Amount,Method,Note,Month\n');
    for (final t in txnsSorted) {
      final c = cycleForDate(t.date);
      final s = stats(c);
      b.writeln([
        t.date.toIso8601String().substring(0, 10),
        t.type.name,
        esc(categoryById(t.categoryId).name),
        t.amount.toStringAsFixed(2),
        t.method,
        esc(t.note),
        esc(cycleName(s.start, s.end)),
      ].join(','));
    }
    return b.toString();
  }

  Future<void> eraseEverything() async {
    settings = Settings();
    categories = defaultCategories();
    txns = [];
    cycles = [];
    recurring = [];
    goals = [];
    _changed();
  }
}
