import 'package:flutter/material.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/emergency/emergency_controller.dart';

class EmergencyAlertOverlay extends StatelessWidget {
  const EmergencyAlertOverlay({required this.controller, super.key});

  final EmergencyController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failed = controller.alertState == EmergencyAlertState.callFailed;
    return Positioned.fill(
      child: Material(
        color: const Color(0xFF450A0A).withValues(alpha: 0.98),
        child: SafeArea(
          child: Semantics(
            liveRegion: true,
            label: failed ? l10n.callFailed : l10n.emergencyCountdown,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    failed ? Icons.phone_disabled : Icons.warning_rounded,
                    size: 96,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    failed ? l10n.callFailed : '${controller.secondsRemaining}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    failed
                        ? l10n.callFailedHint
                        : l10n.callingContactSoon(
                            controller.contact?.name ?? '',
                          ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 36),
                  if (!failed) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                        ),
                        onPressed: controller.cancelAlert,
                        icon: const Icon(Icons.close, size: 32),
                        label: Text(
                          l10n.cancelEmergency,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                        onPressed: controller.callNow,
                        icon: const Icon(Icons.phone, size: 32),
                        label: Text(
                          l10n.callNow,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ] else
                    FilledButton(
                      onPressed: controller.dismissError,
                      child: Text(l10n.dismiss),
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
