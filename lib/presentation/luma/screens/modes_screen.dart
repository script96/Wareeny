import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';
import 'package:wareeny/presentation/luma/luma_routes.dart';
import 'package:wareeny/presentation/luma/widgets/environment_selector_sheet.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class ModesScreen extends StatelessWidget {
  const ModesScreen({
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
          title: 'Modes',
          subtitle: 'Choose one focused task at a time.',
        ),
        const SizedBox(height: AppSpacing.md),
        MainStatusBanner(
          state: controller.uiState,
          title: 'Environment: ${controller.currentEnvironment.label}',
          message:
              'Indoor and Outdoor must be selected manually for better safety and accuracy.',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () async {
            final selected = await showEnvironmentSelectorSheet(
              context,
              selected: controller.currentEnvironment,
            );
            if (selected != null) {
              await controller.switchEnvironment(selected);
            }
          },
          icon: const Icon(Icons.swap_horiz_rounded),
          label: Text('Change to ${controller.currentEnvironment.label}'),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...LumaModeCategory.values.map(
          (category) => _ModeSection(
            title: category.label,
            modes: controller.modesForCategory(category),
            onModeTap: (mode) async {
              await controller.switchMode(mode);
              if (!context.mounted) {
                return;
              }
              await openModeScreen(
                context,
                controller: controller,
                mode: mode,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ModeSection extends StatelessWidget {
  const _ModeSection({
    required this.title,
    required this.modes,
    required this.onModeTap,
  });

  final String title;
  final List<LumaModeDefinition> modes;
  final ValueChanged<LumaModeDefinition> onModeTap;

  @override
  Widget build(BuildContext context) {
    if (modes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...modes.map(
            (mode) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ModeCard(
                mode: mode,
                onTap: () => onModeTap(mode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
