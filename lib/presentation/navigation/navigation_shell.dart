import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/camera/camera_feed_view.dart';
import 'package:wareeny/presentation/emergency/emergency_controller.dart';
import 'package:wareeny/presentation/emergency/emergency_settings_card.dart';
import 'package:wareeny/presentation/home/home_detection_screen.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/navigation_mode/navigation_screen.dart';
import 'package:wareeny/presentation/read/read_screen.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/presentation/settings/settings_screen.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({
    required this.settings,
    required this.emergencyController,
    required this.onManageEmergencyContact,
    super.key,
  });

  final SettingsController settings;
  final EmergencyController emergencyController;
  final VoidCallback onManageEmergencyContact;

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  var _selectedIndex = 0;

  static const _modes = AppMode.values;

  @override
  void initState() {
    super.initState();
    // Speak a greeting in the user's persisted language on first launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = AppLocalizations.of(context);
      final tts = AppScope.of(context).audioHapticsBridge;
      tts.speak(
        l10n.appGreeting,
        languageCode: widget.settings.locale.languageCode,
        speechRate: widget.settings.speechRate,
      );
    });
  }

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
    final l10n = AppLocalizations.of(context);

    // Settings mode: full-screen settings hub (no camera)
    if (_currentMode == AppMode.settings) {
      return SettingsScreen(
        settings: widget.settings,
        onClose: () => _selectMode(AppMode.values.indexOf(AppMode.home)),
        emergencySection: EmergencySettingsCard(
          controller: widget.emergencyController,
          onManageContact: widget.onManageEmergencyContact,
        ),
      );
    }

    if (_currentMode == AppMode.read) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: ReadScreen(
          previousMode: _previousMode,
          nextMode: _nextMode,
          onModeSelect: _selectMode,
          settings: widget.settings,
        ),
      );
    }

    if (_currentMode == AppMode.navigation) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: NavigationScreen(
          previousMode: _previousMode,
          nextMode: _nextMode,
          onPrevious: _selectPreviousMode,
          onNext: _selectNextMode,
          onModeSelect: _selectMode,
          settings: widget.settings,
        ),
      );
    }

    if (_currentMode == AppMode.stuffFinder) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: StuffFinderScreen(
          previousMode: _previousMode,
          nextMode: _nextMode,
          onPrevious: _selectPreviousMode,
          onNext: _selectNextMode,
          onModeSelect: _selectMode,
          settings: widget.settings,
        ),
      );
    }

    if (_currentMode == AppMode.home) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: HomeDetectionScreen(
          previousMode: _previousMode,
          nextMode: _nextMode,
          onPrevious: _selectPreviousMode,
          onNext: _selectNextMode,
          onModeSelect: _selectMode,
          settings: widget.settings,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: TwoFingerSwipeDetector(
        onSwipeLeft: _selectNextMode,
        onSwipeRight: _selectPreviousMode,
        child: Semantics(
          label: l10n.activeModeNamed(_currentMode.labelFor(l10n)),
          hint: l10n.swipeHint,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CameraFeedView(),
              _TopOverlay(currentMode: _currentMode),
              const _RightSideOverlay(),
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
    final l10n = AppLocalizations.of(context);
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.activeModeNamed(_currentMode.labelFor(l10n)),
        widget.settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      );
    }
  }
}

// ── Overlay widgets ───────────────────────────────────────────────────────────

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
      child: Center(child: SafeArea(child: const CameraSideActions())),
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
