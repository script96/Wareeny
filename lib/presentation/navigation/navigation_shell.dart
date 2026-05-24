import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';
import 'package:wareeny/features/indoor_navigation/indoor_navigation_phrases.dart';
import 'package:wareeny/presentation/camera/camera_feed_view.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
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
  ServiceRegistry? _services;
  StreamSubscription? _indoorStateSubscription;
  Timer? _indoorSpeechTimer;
  var _indoorNavigationRunning = false;
  DateTime? _lastIndoorSpeechAt;
  String? _latestIndoorStateText;

  static const _modes = AppMode.values;
  static const _indoorSpeechInterval = Duration(milliseconds: 900);

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncIndoorNavigationMode();
      _speakCurrentMode();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = AppScope.of(context);
  }

  @override
  void dispose() {
    _stopIndoorNavigation();
    super.dispose();
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
              // Full-screen camera feed
              CameraFeedView(
                indoorNavigationActive: _currentMode == AppMode.indoor,
                indoorNavigationBridge: _services!.indoorNavigationBridge,
              ),

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
    _syncIndoorNavigationMode();
    _speakCurrentMode();
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _currentMode.label,
        TextDirection.ltr,
      );
    }
  }

  void _syncIndoorNavigationMode() {
    if (_currentMode == AppMode.indoor) {
      _startIndoorNavigation();
    } else {
      _stopIndoorNavigation();
    }
  }

  void _speakCurrentMode() {
    final services = _services;
    if (services == null) {
      return;
    }

    unawaited(
      services.audioHapticsBridge.speak(
        'الوضع الحالي: ${_currentMode.arabicLabel}',
        interrupt: true,
      ),
    );
  }

  void _startIndoorNavigation() {
    if (_indoorNavigationRunning) {
      return;
    }

    final services = _services;
    if (services == null) {
      return;
    }

    _indoorNavigationRunning = true;
    _lastIndoorSpeechAt = null;
    _latestIndoorStateText = null;
    _indoorStateSubscription = services.indoorNavigationBridge.states().listen((
      state,
    ) {
      _speakLatestIndoorState(services, state.stateText);
    });
    unawaited(services.indoorNavigationBridge.start());
  }

  void _speakLatestIndoorState(ServiceRegistry services, String stateText) {
    _latestIndoorStateText = stateText;
    final now = DateTime.now();
    final lastSpokenAt = _lastIndoorSpeechAt;

    if (lastSpokenAt == null ||
        now.difference(lastSpokenAt) >= _indoorSpeechInterval) {
      _flushIndoorSpeech(services);
      return;
    }

    _indoorSpeechTimer ??= Timer(
      _indoorSpeechInterval - now.difference(lastSpokenAt),
      () {
        _indoorSpeechTimer = null;
        _flushIndoorSpeech(services);
      },
    );
  }

  void _flushIndoorSpeech(ServiceRegistry services) {
    final stateText = _latestIndoorStateText;
    if (stateText == null || !_indoorNavigationRunning) {
      return;
    }

    _lastIndoorSpeechAt = DateTime.now();
    _latestIndoorStateText = null;
    unawaited(
      services.audioHapticsBridge.speak(
        IndoorNavigationPhrases.forPrototypeText(stateText),
        interrupt: true,
      ),
    );
  }

  void _stopIndoorNavigation() {
    if (!_indoorNavigationRunning) {
      return;
    }

    final services = _services;
    _indoorNavigationRunning = false;
    _lastIndoorSpeechAt = null;
    _latestIndoorStateText = null;
    _indoorSpeechTimer?.cancel();
    _indoorSpeechTimer = null;
    unawaited(_indoorStateSubscription?.cancel());
    _indoorStateSubscription = null;
    if (services != null) {
      unawaited(services.indoorNavigationBridge.stop());
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
      child: Center(child: SafeArea(child: const CameraSideActions())),
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
