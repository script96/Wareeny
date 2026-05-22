import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareny/presentation/camera/camera_feed_view.dart';
import 'package:wareny/presentation/navigation/app_mode.dart';
import 'package:wareny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareny/presentation/reusable/two_finger_swipe_detector.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  var _selectedIndex = 0;

  static const _modes = AppMode.values;

  AppMode get _currentMode => _modes[_selectedIndex];

  AppMode get _previousMode {
    final index = (_selectedIndex - 1) % _modes.length;
    return _modes[index];
  }

  AppMode get _nextMode {
    final index = (_selectedIndex + 1) % _modes.length;
    return _modes[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TwoFingerSwipeDetector(
        onSwipeLeft: _selectNextMode,
        onSwipeRight: _selectPreviousMode,
        child: Semantics(
          label: '${_currentMode.label} mode camera feed',
          hint: 'Swipe with two fingers left or right to switch modes.',
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CameraFeedView(),
              _BottomModeMenu(
                previousMode: _previousMode,
                currentMode: _currentMode,
                nextMode: _nextMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectNextMode() {
    _selectMode((_selectedIndex + 1) % _modes.length);
  }

  void _selectPreviousMode() {
    _selectMode((_selectedIndex - 1) % _modes.length);
  }

  void _selectMode(int index) {
    setState(() => _selectedIndex = index);
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _currentMode.label,
        TextDirection.ltr,
      );
    }
  }
}

class _BottomModeMenu extends StatelessWidget {
  const _BottomModeMenu({
    required this.previousMode,
    required this.currentMode,
    required this.nextMode,
  });

  final AppMode previousMode;
  final AppMode currentMode;
  final AppMode nextMode;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Center(
          child: ModeCarouselBar(
            previous: previousMode,
            current: currentMode,
            next: nextMode,
          ),
        ),
      ),
    );
  }
}
