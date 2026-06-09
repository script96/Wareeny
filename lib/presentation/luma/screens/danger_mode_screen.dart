import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class DangerModeScreen extends StatefulWidget {
  const DangerModeScreen({
    required this.controller,
    super.key,
  });

  final LumaController controller;

  @override
  State<DangerModeScreen> createState() => _DangerModeScreenState();
}

class _DangerModeScreenState extends State<DangerModeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.triggerDanger();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(title: const Text('DANGER MODE')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              MainStatusBanner(
                state: controller.uiState,
                title: 'DANGER MODE',
                message: controller.assistantMessage,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.emergencyCrimson,
                  borderRadius: BorderRadius.circular(AppSpacing.lg),
                  border: Border.all(color: AppColors.dangerRed, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Obstacle very close ahead.',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Danger mode interrupts all other modes. Haptic warning, emergency contact call, location sharing, shake gesture activation, and voice command activation are prepared as placeholders.',
                    ),
                  ],
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
                        'Priority order',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('1. Danger alert'),
                      const Text('2. Obstacle warning'),
                      const Text('3. Navigation cue'),
                      const Text('4. OCR result'),
                      const Text('5. AI answer'),
                      const Text('6. General object label'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: controller.callEmergencyContact,
                icon: const Icon(Icons.call_rounded),
                label: const Text(LumaStrings.callEmergency),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  await controller.cancelDangerMode();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text(LumaStrings.cancelDanger),
              ),
            ],
          );
        },
      ),
    );
  }
}
