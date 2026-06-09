import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_data.dart';
import 'package:wareeny/presentation/luma/screens/danger_mode_screen.dart';
import 'package:wareeny/presentation/luma/luma_routes.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';
import 'package:wareeny/presentation/luma/widgets/environment_selector_sheet.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.controller,
    super.key,
  });

  final LumaController controller;

  @override
  Widget build(BuildContext context) {
    final mode = controller.currentMode;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SectionHeader(
          title: 'Wareeny',
          subtitle: 'Voice-first support with simple, safe actions.',
        ),
        const SizedBox(height: AppSpacing.md),
        MainStatusBanner(
          state: controller.uiState,
          title:
              '${controller.uiState.label} - ${controller.currentEnvironment.label}',
          message: controller.assistantMessage,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current mode',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  mode?.title ?? 'No mode selected',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showEnvironmentSelectorSheet(
                      context,
                      selected: controller.currentEnvironment,
                    );
                    if (selected != null) {
                      await controller.switchEnvironment(selected);
                    }
                  },
                  icon: const Icon(Icons.place_rounded),
                  label: Text(
                    'Environment: ${controller.currentEnvironment.label}',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LargeActionButton(
          label: LumaStrings.holdToSpeak,
          icon: Icons.mic_rounded,
          supportingText:
              'Hold to start listening. Tap for a quick voice prompt.',
          onPressed: controller.startListening,
          onLongPressStart: controller.startListening,
          onLongPressEnd: controller.stopListening,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.repeatLastMessage,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Repeat'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: mode == null
                    ? null
                    : () => openModeScreen(
                          context,
                          controller: controller,
                          mode: mode,
                        ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Open Mode'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AssistantSpeechOutput(
          title: 'Last spoken message',
          message: controller.lastSpokenMessage,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested commands',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final command in suggestedCommands)
                      ActionChip(
                        label: Text(command.label),
                        onPressed: () async {
                          await controller.handleSuggestedCommand(command);
                          if (!context.mounted) {
                            return;
                          }
                          if (command.opensDanger) {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    DangerModeScreen(controller: controller),
                              ),
                            );
                            return;
                          }
                          final mode = controller.currentMode;
                          if (mode == null) {
                            return;
                          }
                          await openModeScreen(
                            context,
                            controller: controller,
                            mode: mode,
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice commands shown in the UI',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...LumaStrings.supportedCommands.map(
                  (command) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(command),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
