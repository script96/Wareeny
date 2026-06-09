import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    super.key,
  });

  final LumaController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SectionHeader(
          title: 'Settings',
          subtitle: 'Voice, safety, privacy, performance, and backend placeholders.',
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSection(
          title: 'Voice',
          children: [
            SettingsRow(
              title: 'Assistant voice',
              subtitle: controller.assistantVoice,
              trailing: DropdownButton<String>(
                value: controller.assistantVoice,
                items: const [
                  DropdownMenuItem(value: 'Luma', child: Text('Luma')),
                  DropdownMenuItem(value: 'Calm', child: Text('Calm')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateAssistantVoice(value);
                  }
                },
              ),
            ),
            SettingsRow(
              title: 'Speech speed',
              subtitle: controller.speechSpeed,
              trailing: DropdownButton<String>(
                value: controller.speechSpeed,
                items: const [
                  DropdownMenuItem(value: 'Slow', child: Text('Slow')),
                  DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'Fast', child: Text('Fast')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateSpeechSpeed(value);
                  }
                },
              ),
            ),
            SettingsRow(
              title: 'Repeat last message',
              subtitle: 'Replay the last spoken guidance.',
              trailing: IconButton(
                onPressed: controller.repeatLastMessage,
                icon: const Icon(Icons.replay_rounded),
              ),
            ),
            SettingsRow(
              title: 'Language',
              subtitle: 'Prepared for Arabic and RTL support later.',
              trailing: DropdownButton<String>(
                value: controller.language,
                items: const [
                  DropdownMenuItem(
                    value: LumaStrings.english,
                    child: Text(LumaStrings.english),
                  ),
                  DropdownMenuItem(
                    value: LumaStrings.arabicComingSoon,
                    child: Text(LumaStrings.arabicComingSoon),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateLanguage(value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSection(
          title: 'Haptics',
          children: [
            SettingsRow(
              title: 'Haptics on or off',
              subtitle: 'Prepare vibration hooks for safety feedback.',
              trailing: Switch(
                value: controller.hapticsEnabled,
                onChanged: controller.toggleHaptics,
              ),
            ),
            const SettingsRow(
              title: 'Haptic strength',
              subtitle: 'Placeholder for strength control.',
            ),
            SettingsRow(
              title: 'Danger haptics test',
              subtitle: 'Trigger the warning pattern placeholder.',
              trailing: IconButton(
                onPressed: () => controller.triggerHaptic('danger-test'),
                icon: const Icon(Icons.vibration_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSection(
          title: 'Safety',
          children: [
            const SettingsRow(
              title: 'Emergency contact',
              subtitle: 'Placeholder contact: +20 100 000 0000',
            ),
            SettingsRow(
              title: 'Danger mode',
              subtitle: 'Highest priority safety state.',
              trailing: IconButton(
                onPressed: () => controller.triggerDanger(),
                icon: const Icon(Icons.sos_rounded),
              ),
            ),
            SettingsRow(
              title: 'Shake to activate danger mode',
              subtitle: 'Prepared for future motion activation.',
              trailing: Switch(
                value: controller.shakeToActivateDangerMode,
                onChanged: controller.toggleShakeToActivate,
              ),
            ),
            SettingsRow(
              title: 'Location sharing',
              subtitle: 'Placeholder for emergency location sharing.',
              trailing: Switch(
                value: controller.locationSharingEnabled,
                onChanged: controller.toggleLocationSharing,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSection(
          title: 'Privacy',
          children: [
            SettingsRow(
              title: 'Privacy mode default',
              subtitle: 'Suppress sensitive text unless confirmed.',
              trailing: Switch(
                value: controller.privacyModeEnabled,
                onChanged: controller.togglePrivacyMode,
              ),
            ),
            SettingsRow(
              title: 'Ask before reading sensitive text',
              subtitle: 'Show confirmation when private text appears.',
              trailing: Switch(
                value: controller.askBeforeSensitiveText,
                onChanged: controller.toggleAskBeforeSensitiveText,
              ),
            ),
            SettingsRow(
              title: 'Local-only saved item images',
              subtitle: 'Keep saved item references on device.',
              trailing: Switch(
                value: controller.localOnlySavedImages,
                onChanged: controller.toggleLocalOnlySavedImages,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSection(
          title: 'Performance',
          children: [
            SettingsRow(
              title: 'Battery saving mode',
              subtitle: 'Reduce workload during long sessions.',
              trailing: Switch(
                value: controller.batterySavingMode,
                onChanged: controller.toggleBatterySaving,
              ),
            ),
            SettingsRow(
              title: 'Thermal downgrade',
              subtitle: 'Placeholder status: ${controller.thermalStatus}',
            ),
            SettingsRow(
              title: 'Frame sampling level',
              subtitle: controller.frameSamplingLevel,
              trailing: DropdownButton<String>(
                value: controller.frameSamplingLevel,
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                  DropdownMenuItem(value: 'Balanced', child: Text('Balanced')),
                  DropdownMenuItem(value: 'High', child: Text('High')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateFrameSampling(value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSection(
          title: 'Backend',
          children: [
            SettingsRow(
              title: 'Backend status',
              subtitle: controller.backendStatus,
            ),
            SettingsRow(
              title: 'Health check placeholder',
              subtitle: '${controller.backendUrl}/health',
              trailing: IconButton(
                onPressed: controller.checkBackendHealth,
                icon: const Icon(Icons.health_and_safety_rounded),
              ),
            ),
            const SettingsRow(
              title: 'In-hand detection endpoint placeholder',
              subtitle: 'POST /in-hand/detect',
            ),
          ],
        ),
      ],
    );
  }
}
