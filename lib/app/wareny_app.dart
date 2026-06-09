import 'package:flutter/material.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/theme/app_theme.dart';
import 'package:wareeny/presentation/navigation/navigation_shell.dart';

class WareenyApp extends StatelessWidget {
  const WareenyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppScope.of(context).config;

    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: config.enableDiagnostics,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const NavigationShell(),
    );
  }
}
