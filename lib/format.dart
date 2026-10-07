import 'package:intl/intl.dart';

import 'catalog.dart';
import 'models.dart';

class Fmt {
  Fmt(String currencyCode, {this.hidden = false}) : currency = currencyFor(currencyCode) {
    _full = NumberFormat.currency(locale: currency.locale, symbol: currency.symbol, decimalDigits: 2);
    _whole = NumberFormat.currency(locale: currency.locale, symbol: currency.symbol, decimalDigits: 0);
    _compact = NumberFormat.compactCurrency(locale: currency.locale, symbol: currency.symbol, decimalDigits: 1);
    _plain = NumberFormat.decimalPattern(currency.locale);
  }

  final Currency currency;
  final bool hidden;
  late final NumberFormat _full;
  late final NumberFormat _whole;
  late final NumberFormat _compact;
  late final NumberFormat _plain;

  static const _mask = '••••';

  /// Whole numbers drop the decimals; fractional amounts keep two places.
  String money(double v) {
    if (hidden) return '${currency.symbol}$_mask';
    return v == v.roundToDouble() ? _whole.format(v) : _full.format(v);
  }

  String signed(Txn t) => '${t.isExpense ? '−' : '+'}${money(t.amount)}';

  String compact(double v) {
    if (hidden) return _mask;
    if (v.abs() < 1000) return _whole.format(v);
    return _compact.format(v);
  }

  String plain(double v) => _plain.format(v);
}

final _dMMM = DateFormat('d MMM');
final _dMMMy = DateFormat('d MMM yyyy');
final _eeeDMMM = DateFormat('EEE, d MMM');
final _mmmY = DateFormat('MMMM yyyy');

String dayLabel(DateTime d) {
  final today = dateOnly(DateTime.now());
  final x = dateOnly(d);
  final diff = today.difference(x).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';
  return x.year == today.year ? _eeeDMMM.format(x) : _dMMMy.format(x);
}

String shortDate(DateTime d) =>
    d.year == DateTime.now().year ? _dMMM.format(d) : _dMMMy.format(d);

String longDate(DateTime d) => _dMMMy.format(d);

String rangeLabel(DateTime a, DateTime b) {
  if (a.year == b.year) return '${_dMMM.format(a)} – ${_dMMMy.format(b)}';
  return '${_dMMMy.format(a)} – ${_dMMMy.format(b)}';
}

/// "October 2026" style name. A cycle that starts late in a month is named after
/// the month that holds most of its days.
String cycleName(DateTime start, DateTime end) {
  final mid = start.add(Duration(days: end.difference(start).inDays ~/ 2));
  return _mmmY.format(mid);
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Same day next month, clamped to month length (31 Jan -> 28/29 Feb).
DateTime addMonth(DateTime d, [int months = 1, int? preferredDay]) {
  final total = d.year * 12 + d.month - 1 + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  final day = (preferredDay ?? d.day).clamp(1, lastDay);
  return DateTime(y, m, day);
}

String pct(double v) {
  final p = v * 100;
  if (p.abs() >= 10 || p == p.roundToDouble()) return '${p.round()}%';
  return '${p.toStringAsFixed(1)}%';
}
