import 'package:flutter/material.dart';

class StuffFinderItem {
  const StuffFinderItem({
    required this.detectorLabel,
    required this.arabicLabel,
    required this.icon,
    required this.aliases,
  });

  final String detectorLabel;
  final String arabicLabel;
  final IconData icon;
  final List<String> aliases;
}

const stuffFinderItems = <StuffFinderItem>[
  StuffFinderItem(
    detectorLabel: 'wallet',
    arabicLabel: 'محفظة',
    icon: Icons.account_balance_wallet_outlined,
    aliases: ['محفظة', 'المحفظة', 'بوك', 'والت'],
  ),
  StuffFinderItem(
    detectorLabel: 'glasses',
    arabicLabel: 'نظارة',
    icon: Icons.visibility_outlined,
    aliases: ['نظارة', 'النظارة', 'نضارة', 'النضارة'],
  ),
  StuffFinderItem(
    detectorLabel: 'cell phone',
    arabicLabel: 'موبايل',
    icon: Icons.smartphone_outlined,
    aliases: ['موبايل', 'الموبايل', 'تليفون', 'التليفون', 'هاتف', 'فون'],
  ),
  StuffFinderItem(
    detectorLabel: 'bottle',
    arabicLabel: 'زجاجة',
    icon: Icons.local_drink_outlined,
    aliases: ['زجاجة', 'الزجاجة', 'ازازة', 'الازازة', 'مايه', 'مياه'],
  ),
  StuffFinderItem(
    detectorLabel: 'cup',
    arabicLabel: 'كوب',
    icon: Icons.coffee_outlined,
    aliases: ['كوب', 'الكوب', 'كوباية', 'الكوباية', 'مج'],
  ),
  StuffFinderItem(
    detectorLabel: 'chair',
    arabicLabel: 'كرسي',
    icon: Icons.chair_outlined,
    aliases: ['كرسي', 'الكرسي'],
  ),
  StuffFinderItem(
    detectorLabel: 'keys',
    arabicLabel: 'مفاتيح',
    icon: Icons.key_outlined,
    aliases: ['مفاتيح', 'المفاتيح', 'مفتاح', 'المفتاح'],
  ),
  StuffFinderItem(
    detectorLabel: 'backpack',
    arabicLabel: 'شنطة',
    icon: Icons.backpack_outlined,
    aliases: ['شنطة', 'الشنطة', 'حقيبة', 'الحقيبة', 'باك باك'],
  ),
  StuffFinderItem(
    detectorLabel: 'book',
    arabicLabel: 'كتاب',
    icon: Icons.menu_book_outlined,
    aliases: ['كتاب', 'الكتاب', 'كراسة', 'الكراسة'],
  ),
  StuffFinderItem(
    detectorLabel: 'microwave',
    arabicLabel: 'ميكروويف',
    icon: Icons.microwave_outlined,
    aliases: ['ميكروويف', 'الميكروويف', 'مايكروويف'],
  ),
];

const customStuffFinderClasses = <String>{'wallet', 'glasses', 'keys'};

final stuffFinderClasses = List<String>.unmodifiable(
  stuffFinderItems.map((item) => item.detectorLabel),
);

StuffFinderItem? stuffFinderItemForLabel(String label) {
  final normalized = label.trim().toLowerCase();
  for (final item in stuffFinderItems) {
    if (item.detectorLabel == normalized) return item;
  }
  return null;
}

bool isCustomStuffFinderClass(String label) {
  return customStuffFinderClasses.contains(label.trim().toLowerCase());
}

String get availableStuffFinderItemsArabic =>
    stuffFinderItems.map((item) => item.arabicLabel).join('، ');
