import 'package:flutter/material.dart';

enum AppMode {
  home('Home', Icons.home_outlined),
  navigation('Navigation', Icons.assistant_navigation),
  stuffFinder('Stuff Finder', Icons.search_outlined),
  inHand('In-hand', Icons.back_hand_outlined),
  read('Read', Icons.menu_book_outlined),
  settings('Settings', Icons.settings_outlined);

  const AppMode(this.label, this.icon);

  final String label;
  final IconData icon;
}
