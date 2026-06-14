import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/presentation/navigation_mode/navigation_controller.dart';

class NavigationDebugPanel extends StatelessWidget {
  const NavigationDebugPanel({
    required this.controller,
    required this.enabled,
    required this.onToggle,
    super.key,
  });

  final NavigationController controller;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final frame = controller.latestFrame?.source;
    final noFrames = controller.framesReceived == 0;
    final labels = controller.latestDetectionLabels.isEmpty
        ? 'none'
        : controller.latestDetectionLabels.join(', ');
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: noFrames ? AppColors.alertRed : AppColors.electricGreen,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.detectorStatus,
                style: TextStyle(
                  color: noFrames
                      ? AppColors.alertRed
                      : AppColors.electricGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  'Inference frames: ${controller.framesReceived}',
                  'Active detector: ${controller.activeDetectorSource}',
                  'Frames with objects: ${controller.framesWithDetections}',
                  'Total objects: ${controller.totalDetections}',
                  if (frame != null) 'Last frame ID: ${frame.frameId}',
                  'Current objects: ${frame?.detections.length ?? 0}',
                  'Detected: $labels',
                  if (frame?.inferenceTime != null)
                    'Inference: ${frame!.inferenceTime!.inMilliseconds} ms',
                  if (frame?.framesPerSecond != null)
                    'Model FPS: ${frame!.framesPerSecond!.toStringAsFixed(1)}',
                  if (controller.sceneLuminance != null)
                    'Light: ${controller.sceneLuminance!.toStringAsFixed(0)} / 255',
                  if (controller.darkPixelRatio != null)
                    'Dark pixels: ${(controller.darkPixelRatio! * 100).toStringAsFixed(0)}%',
                  'Light state: ${controller.lightCondition.name}',
                  'Dark for: ${(controller.darkDuration.inMilliseconds / 1000).toStringAsFixed(1)} s',
                  'Flash requested: ${controller.flashRequested ? "YES" : "NO"}',
                  'Torch: ${controller.torchEnabled ? "ON" : "OFF"}',
                  'Risk: ${controller.assessment.highestRisk.name}',
                  if (enabled) 'Feedback: ${controller.cooldownStatus}',
                  if (enabled && controller.latestMessage.isNotEmpty)
                    'Latest warning: ${controller.latestMessage}',
                ].join('\n'),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 5),
              Semantics(
                button: true,
                label: enabled
                    ? 'Hide detailed navigation diagnostics'
                    : 'Show detailed navigation diagnostics',
                child: GestureDetector(
                  onTap: onToggle,
                  child: Text(
                    enabled ? 'HIDE DETAILS' : 'SHOW DETAILS',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
