import 'package:flutter/material.dart';

enum AppMode {
  home('Home', Icons.home_outlined),
  stuffFinder('Stuff Finder', Icons.search_outlined),
  indoor('Indoor', Icons.apartment_outlined),
  outdoor('Outdoor', Icons.explore_outlined),
  read('Read', Icons.menu_book_outlined),
  ask('Ask', Icons.question_answer_outlined),
  inHand('In-hand', Icons.back_hand_outlined),
  settings('Settings', Icons.settings_outlined);

  const AppMode(this.label, this.icon);

  final String label;
  final IconData icon;
}
