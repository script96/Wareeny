import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/emergency/emergency_controller.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/camera/camera_feed_view.dart';
import 'package:wareeny/presentation/emergency/emergency_overlay.dart';
import 'package:wareeny/presentation/home/home_detection_screen.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/navigation_mode/navigation_screen.dart';
import 'package:wareeny/presentation/onboarding/emergency_onboarding_screen.dart';
import 'package:wareeny/presentation/read/read_screen.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/hold_to_listen_detector.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/presentation/settings/settings_screen.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_screen.dart';
import 'package:wareeny/presentation/voice/voice_interaction_controller.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({required this.settings, super.key});

  final SettingsController settings;

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  var _selectedIndex = 0;
  late EmergencyController _emergencyController;
  late VoiceInteractionController _voiceInteractionController;

  static const _modes = AppMode.values;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.of(context);
    _emergencyController = services.emergencyController;
    _voiceInteractionController = services.voiceInteractionController;
    _voiceInteractionController.bindModeSelection(_selectModeFromVoice);
  }

  @override
  void initState() {
    super.initState();
    // Speak a greeting in the user's persisted language on first launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scope = AppScope.of(context);
      final l10n = AppLocalizations.of(context);
      final tts = scope.audioHapticsBridge;
      tts.speak(
        l10n.appGreeting,
        languageCode: widget.settings.locale.languageCode,
        speechRate: widget.settings.speechRate,
      );

      // Arm the emergency controller and wire overlay callback.
      final emergency = _emergencyController;
      emergency.onCountdownStarted = () {
        if (!mounted) return;
        showEmergencyOverlay(context, emergency);
      };
      emergency.arm();

      // Show onboarding on very first launch.
      if (!widget.settings.hasSeenEmergencyOnboarding) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) =>
                EmergencyOnboardingScreen(settings: widget.settings),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _emergencyController.disarm();
    _voiceInteractionController.clearModeSelection();
    super.dispose();
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
    return HoldToListenDetector(
      onHoldStart: _voiceInteractionController.startHoldListening,
      onHoldEnd: _voiceInteractionController.endHoldListening,
      onHoldCancel: _voiceInteractionController.cancelHoldListening,
      child: _buildCurrentMode(context),
    );
  }

  Widget _buildCurrentMode(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Settings mode: full-screen settings hub (no camera)
    if (_currentMode == AppMode.settings) {
      return SettingsScreen(
        settings: widget.settings,
        onClose: () => _selectMode(AppMode.values.indexOf(AppMode.home)),
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
    _selectModeInternal(index, promptForStuffFinder: true);
  }

  void _selectModeFromVoice(AppMode mode) {
    _selectModeInternal(
      AppMode.values.indexOf(mode),
      promptForStuffFinder: false,
    );
  }

  void _selectModeInternal(int index, {required bool promptForStuffFinder}) {
    final changed = _selectedIndex != index;
    setState(() => _selectedIndex = index);
    final l10n = AppLocalizations.of(context);
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.activeModeNamed(_currentMode.labelFor(l10n)),
        widget.settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      );
    }
    if (changed &&
        promptForStuffFinder &&
        _currentMode == AppMode.stuffFinder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentMode == AppMode.stuffFinder) {
          unawaited(
            _voiceInteractionController.beginStuffFinderItemListening(),
          );
        }
      });
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
