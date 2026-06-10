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
    return Semantics(
      button: true,
      label: enabled
          ? 'Disable navigation debug overlay'
          : 'Enable navigation debug overlay',
      child: GestureDetector(
        onTap: onToggle,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 310),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: enabled
                      ? AppColors.electricGreen
                      : AppColors.glassBorder,
                ),
              ),
              child: enabled
                  ? Text(
                      [
                        controller.detectorStatus,
                        'Objects: ${controller.assessment.objects.length}  '
                            'Risk: ${controller.assessment.highestRisk.name}',
                        if (frame?.inferenceTime != null)
                          'Inference: ${frame!.inferenceTime!.inMilliseconds} ms',
                        if (frame?.framesPerSecond != null)
                          'FPS: ${frame!.framesPerSecond!.toStringAsFixed(1)}',
                        'Feedback: ${controller.cooldownStatus}',
                        if (controller.latestMessage.isNotEmpty)
                          'Latest: ${controller.latestMessage}',
                      ].join('\n'),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bug_report_outlined, color: Colors.white70),
                        SizedBox(width: 6),
                        Text(
                          'DEBUG',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
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
