import 'package:flutter/material.dart';

enum AppMode {
  home('Home', 'الرئيسية', Icons.home_outlined),
  indoor('Indoor', 'التنقل داخل البيت', Icons.apartment_outlined),
  outdoor('Outdoor', 'التنقل بره البيت', Icons.explore_outlined),
  read('Read', 'قراءة النصوص', Icons.menu_book_outlined),
  ask('Ask', 'اسأل', Icons.question_answer_outlined),
  inHand('In-hand', 'الحاجات اللي في إيدك', Icons.back_hand_outlined),
  settings('Settings', 'الإعدادات', Icons.settings_outlined);

  const AppMode(this.label, this.arabicLabel, this.icon);

  final String label;
  final String arabicLabel;
  final IconData icon;
}
