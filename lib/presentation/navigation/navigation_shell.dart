import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareny/presentation/camera/camera_feed_view.dart';
import 'package:wareny/presentation/navigation/app_mode.dart';
import 'package:wareny/presentation/reusable/camera_side_actions.dart';
import 'package:wareny/presentation/reusable/camera_top_bar.dart';
import 'package:wareny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareny/presentation/stuff_finder/stuff_finder_screen.dart';

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
      backgroundColor: Colors.black,
      body: TwoFingerSwipeDetector(
        onSwipeLeft: _selectNextMode,
        onSwipeRight: _selectPreviousMode,
        child: Semantics(
          label: '${_currentMode.label} mode camera feed',
          hint: 'Swipe with two fingers left or right to switch modes.',
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ModeBody(currentMode: _currentMode),

              // Top HUD bar
              _TopOverlay(currentMode: _currentMode),

              // Right side action buttons
              const _RightSideOverlay(),

              // Bottom mode selector
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

// ── Overlay widgets ──────────────────────────────────────────────────────────

class _ModeBody extends StatelessWidget {
  const _ModeBody({required this.currentMode});

  final AppMode currentMode;

  @override
  Widget build(BuildContext context) {
    return switch (currentMode) {
      AppMode.stuffFinder => const StuffFinderScreen(),
      _ => const CameraFeedView(),
    };
  }
}

class _TopOverlay extends StatelessWidget {
  const _TopOverlay({required this.currentMode});

  final AppMode currentMode;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: CameraTopBar(currentMode: currentMode),
      ),
    );
  }
}

class _RightSideOverlay extends StatelessWidget {
  const _RightSideOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: SafeArea(
          child: const CameraSideActions(),
        ),
      ),
    );
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
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
