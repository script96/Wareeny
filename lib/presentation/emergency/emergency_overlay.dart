import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/emergency/emergency_controller.dart';
import 'package:wareeny/core/localization/app_localizations.dart';

/// Full-screen SOS countdown overlay. Shown for 3 seconds before the emergency
/// call is dispatched. The user can cancel by tapping anywhere.
///
/// Usage: Push this route modally when [EmergencyController.onCountdownStarted]
/// fires. It auto-dismisses when the countdown ends or is cancelled.
class EmergencyOverlay extends StatefulWidget {
  const EmergencyOverlay({required this.controller, super.key});

  final EmergencyController controller;

  @override
  State<EmergencyOverlay> createState() => _EmergencyOverlayState();
}

class _EmergencyOverlayState extends State<EmergencyOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _uiTimer;
  int _secondsLeft = 5;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    // Pulsing animation for the SOS icon.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.85, end: 1.15).animate(_pulseController);

    // Keep the UI countdown in sync with the controller.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = widget.controller.secondsLeft);
      if (!widget.controller.isCountdownActive && !_dismissed) {
        _dismiss();
      }
    });

    // Wire up controller callbacks so we hear about cancel/trigger.
    widget.controller.onCountdownCancelled = _dismiss;
    widget.controller.onEmergencyTriggered = _dismiss;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _uiTimer?.cancel();
    super.dispose();
  }

  void _cancel() {
    widget.controller.cancelCountdown();
    // Callback above will call _dismiss.
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _uiTimer?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Tap anywhere to cancel.
        onTap: _cancel,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC8B0000), Color(0xEE1A0000)],
            ),
          ),
          child: SafeArea(
            child: Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ── Pulsing SOS icon ───────────────────────────────────────
                  Semantics(
                    label: isAr
                        ? 'وضع الطوارئ. جارٍ الاتصال.'
                        : 'Emergency mode. Calling now.',
                    liveRegion: true,
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.shade900,
                          border: Border.all(
                            color: Colors.red.shade300,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withAlpha(120),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Countdown number ───────────────────────────────────────
                  Text(
                    '$_secondsLeft',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr ? 'جارٍ الاتصال خلال...' : 'Auto-calling in...',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const Spacer(),

                  // ── Cancel button ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                    child: Semantics(
                      button: true,
                      label: isAr ? 'إلغاء الطوارئ' : 'Cancel emergency',
                      child: GestureDetector(
                        onTap: _cancel,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white38,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            isAr ? 'اضغط للإلغاء' : 'TAP TO CANCEL',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [EmergencyOverlay] as a full-screen modal route.
void showEmergencyOverlay(
    BuildContext context, EmergencyController controller) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, a, b) =>
          EmergencyOverlay(controller: controller),
      transitionsBuilder: (ctx, animation, a, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    ),
  );
  SemanticsService.sendAnnouncement(
    View.of(context),
    'Emergency mode activated',
    TextDirection.ltr,
  );
}
