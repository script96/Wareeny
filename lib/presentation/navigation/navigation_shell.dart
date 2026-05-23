import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/presentation/camera/camera_feed_view.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/read/read_screen.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';

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
    if (_currentMode == AppMode.read) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: ReadScreen(
          previousMode: _previousMode,
          nextMode: _nextMode,
          onModeSelect: _selectMode,
        ),
      );
    }

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
              // Full-screen camera feed
              const CameraFeedView(),

              // Top HUD bar
              _TopOverlay(currentMode: _currentMode),

              // Right side action buttons
              const _RightSideOverlay(),

              // Bottom mode selector
              _BottomModeMenu(
                previousMode: _previousMode,
                currentMode: _currentMode,
                nextMode: _nextMode,
                onPreviousTap: _selectPreviousMode,
                onNextTap: _selectNextMode,
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
    required this.onPreviousTap,
    required this.onNextTap,
  });

  final AppMode previousMode;
  final AppMode currentMode;
  final AppMode nextMode;
  final VoidCallback onPreviousTap;
  final VoidCallback onNextTap;

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
            onPreviousTap: onPreviousTap,
            onNextTap: onNextTap,
          ),
        ),
      ),
    );
  }
}
