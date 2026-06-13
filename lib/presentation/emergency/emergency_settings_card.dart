import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/presentation/emergency/emergency_controller.dart';

class EmergencySettingsCard extends StatelessWidget {
  const EmergencySettingsCard({
    required this.controller,
    required this.onManageContact,
    super.key,
  });

  final EmergencyController controller;
  final VoidCallback onManageContact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: AppColors.glassWhite,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.safetyMonitoring,
              style: const TextStyle(
                color: AppColors.electricGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.foregroundFallDetection,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                l10n.foregroundFallDetectionHint,
                style: const TextStyle(color: Colors.white60),
              ),
              value: controller.monitoringEnabled,
              onChanged: controller.setMonitoringEnabled,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.shareEmergencyLocation,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                l10n.shareEmergencyLocationHint,
                style: const TextStyle(color: Colors.white60),
              ),
              value: controller.locationSharingEnabled,
              onChanged: controller.setLocationSharingEnabled,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.contact_phone,
                color: AppColors.electricGreen,
              ),
              title: Text(
                controller.contact?.name ?? l10n.emergencyContactTitle,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                controller.contact?.phoneNumber ?? '',
                style: const TextStyle(color: Colors.white60),
              ),
              trailing: const Icon(Icons.edit, color: Colors.white70),
              onTap: onManageContact,
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
              onPressed: () => _confirmRemoval(context),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.removeEmergencyContact),
            ),
            if (AppScope.of(context).config.clerkEnabled) ...[
              const Divider(color: Colors.white24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.account,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const ClerkUserButton(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeEmergencyContact),
        content: Text(l10n.removeEmergencyContactConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelEmergency),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeContact();
  }
}
