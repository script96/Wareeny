import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';

Future<LumaEnvironment?> showEnvironmentSelectorSheet(
  BuildContext context, {
  required LumaEnvironment selected,
}) {
  return showModalBottomSheet<LumaEnvironment>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LumaStrings.chooseEnvironmentTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                LumaStrings.chooseEnvironmentNote,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _EnvironmentOption(
                title: 'Indoor',
                description:
                    'For rooms, halls, doors, stairs, elevators, furniture, and indoor obstacles.',
                selected: selected == LumaEnvironment.indoor,
                onTap: () => Navigator.of(context).pop(LumaEnvironment.indoor),
              ),
              const SizedBox(height: AppSpacing.sm),
              _EnvironmentOption(
                title: 'Outdoor',
                description:
                    'For streets, traffic lights, vehicles, poles, curbs, entrances, ATMs, benches, and public spaces.',
                selected: selected == LumaEnvironment.outdoor,
                onTap: () => Navigator.of(context).pop(LumaEnvironment.outdoor),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _EnvironmentOption extends StatelessWidget {
  const _EnvironmentOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<bool>(
                value: true,
                groupValue: selected,
                onChanged: (_) => onTap(),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(description),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
