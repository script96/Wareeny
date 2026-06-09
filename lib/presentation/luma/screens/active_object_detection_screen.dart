import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';
import 'package:wareeny/presentation/luma/screens/danger_mode_screen.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class ActiveObjectDetectionScreen extends StatefulWidget {
  const ActiveObjectDetectionScreen({
    required this.controller,
    required this.mode,
    super.key,
  });

  final LumaController controller;
  final LumaModeDefinition mode;

  @override
  State<ActiveObjectDetectionScreen> createState() =>
      _ActiveObjectDetectionScreenState();
}

class _ActiveObjectDetectionScreenState
    extends State<ActiveObjectDetectionScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.startCameraMode(widget.mode);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.detectionSnapshot;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode.title),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              MainStatusBanner(
                state: controller.uiState,
                title:
                    '${widget.mode.title} - ${controller.currentEnvironment.label}',
                message: controller.assistantMessage,
              ),
              const SizedBox(height: AppSpacing.md),
              const CameraPreviewPlaceholder(
                label: 'Object detection preview',
                overlays: [
                  Alignment.center,
                  Alignment.topRight,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AssistantSpeechOutput(
                title: 'Main spoken output',
                message: snapshot.summary,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  StatusInfoChip(label: 'Direction', value: snapshot.direction),
                  const SizedBox(width: AppSpacing.sm),
                  StatusInfoChip(label: 'Distance', value: snapshot.proximity),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  StatusInfoChip(label: 'Confidence', value: snapshot.confidence),
                  const SizedBox(width: AppSpacing.sm),
                  const StatusInfoChip(
                    label: 'Cooldown',
                    value: 'Active',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Behavior notes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Normal labels use cooldown placeholders. Danger and obstacle feedback interrupt normal guidance. Haptic calls are ready for integration.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton(
                    onPressed: () async {
                      await controller.stopCameraMode();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Stop'),
                  ),
                  OutlinedButton(
                    onPressed: controller.repeatLastMessage,
                    child: const Text('Repeat'),
                  ),
                  OutlinedButton(
                    onPressed: controller.cycleDetectionTarget,
                    child: const Text('Change Target'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DangerModeScreen(controller: controller),
                      ),
                    ),
                    child: const Text('Danger'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
