import 'package:flutter/material.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/screens/danger_mode_screen.dart';
import 'package:wareeny/presentation/luma/screens/home_screen.dart';
import 'package:wareeny/presentation/luma/screens/intro_screen.dart';
import 'package:wareeny/presentation/luma/screens/modes_screen.dart';
import 'package:wareeny/presentation/luma/screens/saved_items_screen.dart';
import 'package:wareeny/presentation/luma/screens/settings_screen.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class LumaShell extends StatefulWidget {
  const LumaShell({super.key});

  @override
  State<LumaShell> createState() => _LumaShellState();
}

class _LumaShellState extends State<LumaShell> {
  LumaController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= LumaController(config: AppScope.of(context).config);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.introCompleted) {
          return IntroScreen(
            controller: controller,
            onStart: controller.completeIntro,
          );
        }

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: controller.currentSection.index,
              children: [
                HomeScreen(controller: controller),
                ModesScreen(controller: controller),
                SavedItemsScreen(controller: controller),
                SettingsScreen(controller: controller),
              ],
            ),
          ),
          bottomNavigationBar: LumaBottomNavigation(
            currentSection: controller.currentSection,
            onSelect: controller.selectSection,
          ),
          floatingActionButton: DangerShortcutButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DangerModeScreen(controller: controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
