import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_theme.dart';
import 'package:wareeny/presentation/navigation/navigation_shell.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

class WareenyApp extends StatelessWidget {
  const WareenyApp({required this.settings, super.key});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: settings.isArabic ? 'ويرني' : 'Wareeny',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          // Active locale drives RTL/LTR layout automatically via Flutter
          locale: settings.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: NavigationShell(settings: settings),
        );
      },
    );
  }
}
