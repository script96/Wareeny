import 'package:flutter/material.dart';

import '../screens/permission/permission_gate.dart';
import '../theme/app_theme.dart';

class WareneApp extends StatelessWidget {
  const WareneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warene',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const PermissionGate(),
    );
  }
}
