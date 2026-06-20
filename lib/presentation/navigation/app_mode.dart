import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

enum AppMode {
  home('Home', Icons.home_outlined),
  navigation('Navigation', Icons.assistant_navigation),
  stuffFinder('Stuff Finder', Icons.search_outlined),
  scan('Scan', Icons.document_scanner_outlined),
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
      AppMode.scan => l10n.modeScan,
      AppMode.read => l10n.modeRead,
      AppMode.settings => l10n.modeSettings,
    };
  }

  /// Returns custom accessibility actions for quick mode switching.
  Map<CustomSemanticsAction, VoidCallback> getModeSwitchActions({
    required AppLocalizations l10n,
    required SettingsController settings,
    required void Function(int) onModeSelect,
  }) {
    final actions = <CustomSemanticsAction, VoidCallback>{};
    for (final mode in AppMode.values) {
      if (mode != this) {
        final actionLabel = settings.isArabic
            ? 'الذهاب إلى وضع ${mode.labelFor(l10n)}'
            : 'Switch to ${mode.labelFor(l10n)} Mode';
        actions[CustomSemanticsAction(label: actionLabel)] = () {
          onModeSelect(AppMode.values.indexOf(mode));
        };
      }
    }
    return actions;
  }
}

