import 'package:flutter/material.dart';

import 'package:wareeny/core/localization/app_localizations.dart';

enum AppMode {
  home('Home', Icons.home_outlined),
  navigation('Navigation', Icons.assistant_navigation),
  stuffFinder('Stuff Finder', Icons.search_outlined),
  inHand('In-hand', Icons.back_hand_outlined),
  read('Read', Icons.menu_book_outlined),
  settings('Settings', Icons.settings_outlined);

  const AppMode(this.label, this.icon);

  /// Hardcoded English label — use [labelFor] for localized display.
  final String label;
  final IconData icon;

  /// Returns the localized display label for this mode.
  String labelFor(AppLocalizations l10n) {
    return switch (this) {
      AppMode.home => l10n.modeHome,
      AppMode.navigation => l10n.modeNavigation,
      AppMode.stuffFinder => l10n.modeStuffFinder,
      AppMode.inHand => l10n.modeInHand,
      AppMode.read => l10n.modeRead,
      AppMode.settings => l10n.modeSettings,
    };
  }
}

