import 'package:flutter/material.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/emergency/emergency_alert_overlay.dart';
import 'package:wareeny/presentation/emergency/emergency_controller.dart';
import 'package:wareeny/presentation/navigation/navigation_shell.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

class EmergencyExperience extends StatelessWidget {
  const EmergencyExperience({
    required this.settings,
    required this.controller,
    required this.onManageContact,
    super.key,
  });

  final SettingsController settings;
  final EmergencyController controller;
  final VoidCallback onManageContact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        NavigationShell(
          settings: settings,
          emergencyController: controller,
          onManageEmergencyContact: onManageContact,
        ),
        PositionedDirectional(
          end: 18,
          bottom: 104,
          child: SafeArea(
            child: Semantics(
              button: true,
              label: l10n.manualSos,
              hint: l10n.manualSosHint,
              child: FloatingActionButton.large(
                heroTag: 'manual-sos',
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                onPressed: controller.startManualSos,
                child: const Icon(Icons.sos, size: 40),
              ),
            ),
          ),
        ),
        if (controller.isAlertActive)
          EmergencyAlertOverlay(controller: controller),
      ],
    );
  }
}
