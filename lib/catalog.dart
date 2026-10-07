import 'package:flutter/material.dart';

import 'models.dart';

/// Icons are stored by key (not code point) so release builds can tree-shake fonts.
const Map<String, IconData> kIcons = {
  'food': Icons.restaurant_rounded,
  'coffee': Icons.local_cafe_rounded,
  'groceries': Icons.local_grocery_store_rounded,
  'transport': Icons.directions_bus_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'car': Icons.directions_car_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'bills': Icons.receipt_long_rounded,
  'rent': Icons.home_rounded,
  'utilities': Icons.bolt_rounded,
  'phone': Icons.smartphone_rounded,
  'internet': Icons.wifi_rounded,
  'entertainment': Icons.movie_rounded,
  'games': Icons.sports_esports_rounded,
  'health': Icons.favorite_rounded,
  'medical': Icons.medical_services_rounded,
  'fitness': Icons.fitness_center_rounded,
  'education': Icons.school_rounded,
  'books': Icons.menu_book_rounded,
  'travel': Icons.flight_takeoff_rounded,
  'hotel': Icons.hotel_rounded,
  'subscriptions': Icons.autorenew_rounded,
  'personal': Icons.spa_rounded,
  'clothing': Icons.checkroom_rounded,
  'gifts': Icons.card_giftcard_rounded,
  'family': Icons.family_restroom_rounded,
  'pets': Icons.pets_rounded,
  'investments': Icons.trending_up_rounded,
  'insurance': Icons.shield_rounded,
  'emi': Icons.account_balance_rounded,
  'charity': Icons.volunteer_activism_rounded,
  'salary': Icons.work_rounded,
  'freelance': Icons.laptop_mac_rounded,
  'business': Icons.storefront_rounded,
  'interest': Icons.percent_rounded,
  'refund': Icons.replay_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'savings': Icons.savings_rounded,
  'house': Icons.cottage_rounded,
  'bike': Icons.two_wheeler_rounded,
  'laptop': Icons.computer_rounded,
  'beach': Icons.beach_access_rounded,
  'ring': Icons.diamond_rounded,
  'baby': Icons.child_friendly_rounded,
  'music': Icons.music_note_rounded,
  'tools': Icons.build_rounded,
  'other': Icons.category_rounded,
};

IconData iconFor(String key) => kIcons[key] ?? Icons.category_rounded;

const List<int> kPalette = [
  0xFFEF4444, // red
  0xFFF97316, // orange
  0xFFF59E0B, // amber
  0xFF84CC16, // lime
  0xFF22C55E, // green
  0xFF10B981, // emerald
  0xFF14B8A6, // teal
  0xFF06B6D4, // cyan
  0xFF0EA5E9, // sky
  0xFF3B82F6, // blue
  0xFF6366F1, // indigo
  0xFF8B5CF6, // violet
  0xFFA855F7, // purple
  0xFFD946EF, // fuchsia
  0xFFEC4899, // pink
  0xFFF43F5E, // rose
  0xFF78716C, // stone
  0xFF64748B, // slate
];

const List<int> kAccents = [
  0xFF4F46E5, // indigo
  0xFF7C3AED, // violet
  0xFF0EA5E9, // sky
  0xFF059669, // emerald
  0xFF0D9488, // teal
  0xFFE11D48, // rose
  0xFFEA580C, // orange
  0xFF334155, // graphite
];

const List<String> kMethods = ['UPI', 'Cash', 'Card', 'Bank', 'Wallet', 'Other'];

IconData methodIcon(String m) => switch (m) {
      'UPI' => Icons.qr_code_rounded,
      'Cash' => Icons.payments_rounded,
      'Card' => Icons.credit_card_rounded,
      'Bank' => Icons.account_balance_rounded,
      'Wallet' => Icons.account_balance_wallet_rounded,
      _ => Icons.more_horiz_rounded,
    };

class Currency {
  const Currency(this.code, this.symbol, this.locale, this.name);
  final String code;
  final String symbol;
  final String locale;
  final String name;
}

const List<Currency> kCurrencies = [
  Currency('INR', '₹', 'en_IN', 'Indian Rupee'),
  Currency('USD', '\$', 'en_US', 'US Dollar'),
  Currency('EUR', '€', 'en_IE', 'Euro'),
  Currency('GBP', '£', 'en_GB', 'British Pound'),
  Currency('AED', 'AED ', 'en_US', 'UAE Dirham'),
  Currency('SAR', 'SAR ', 'en_US', 'Saudi Riyal'),
  Currency('JPY', '¥', 'en_US', 'Japanese Yen'),
  Currency('AUD', 'A\$', 'en_AU', 'Australian Dollar'),
  Currency('CAD', 'C\$', 'en_CA', 'Canadian Dollar'),
  Currency('SGD', 'S\$', 'en_SG', 'Singapore Dollar'),
];

Currency currencyFor(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

List<Category> defaultCategories() {
  Category e(String id, String name, String icon, int color) =>
      Category(id: id, name: name, icon: icon, color: color, type: TxType.expense);
  Category i(String id, String name, String icon, int color) =>
      Category(id: id, name: name, icon: icon, color: color, type: TxType.income);
  return [
    e('food', 'Food & Dining', 'food', 0xFFF97316),
    e('groceries', 'Groceries', 'groceries', 0xFF22C55E),
    e('transport', 'Transport', 'transport', 0xFF0EA5E9),
    e('fuel', 'Fuel', 'fuel', 0xFF64748B),
    e('shopping', 'Shopping', 'shopping', 0xFFEC4899),
    e('bills', 'Bills & Utilities', 'bills', 0xFFF59E0B),
    e('rent', 'Rent', 'rent', 0xFF8B5CF6),
    e('subscriptions', 'Subscriptions', 'subscriptions', 0xFF6366F1),
    e('entertainment', 'Entertainment', 'entertainment', 0xFFD946EF),
    e('health', 'Health', 'health', 0xFFEF4444),
    e('education', 'Education', 'education', 0xFF3B82F6),
    e('travel', 'Travel', 'travel', 0xFF06B6D4),
    e('personal', 'Personal Care', 'personal', 0xFF14B8A6),
    e('gifts', 'Gifts', 'gifts', 0xFFF43F5E),
    e('emi', 'EMI & Loans', 'emi', 0xFF78716C),
    e('investments', 'Investments', 'investments', 0xFF10B981),
    e('other', 'Other', 'other', 0xFF94A3B8),
    i('salary', 'Salary', 'salary', 0xFF10B981),
    i('freelance', 'Freelance', 'freelance', 0xFF0EA5E9),
    i('business', 'Business', 'business', 0xFF8B5CF6),
    i('interest', 'Interest', 'interest', 0xFFF59E0B),
    i('refund', 'Refund', 'refund', 0xFF14B8A6),
    i('gift_in', 'Gifts', 'gifts', 0xFFEC4899),
    i('other_in', 'Other Income', 'wallet', 0xFF94A3B8),
  ];
}
