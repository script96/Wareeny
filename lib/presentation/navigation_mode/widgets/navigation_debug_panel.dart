import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/navigation_mode/navigation_controller.dart';
import 'package:wareeny/shared/danger/danger_detection_service.dart';

enum _DebugPanelSize { collapsed, compact, expanded }

class NavigationDebugPanel extends StatefulWidget {
  const NavigationDebugPanel({
    required this.controller,
    required this.dangerDetection,
    required this.enabled,
    required this.onToggle,
    super.key,
  });

  final NavigationController controller;
  final DangerDetectionService? dangerDetection;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  State<NavigationDebugPanel> createState() => _NavigationDebugPanelState();
}

class _NavigationDebugPanelState extends State<NavigationDebugPanel> {
  _DebugPanelSize _size = _DebugPanelSize.compact;

  void _cycleSize() {
    setState(() {
      _size = switch (_size) {
        _DebugPanelSize.collapsed => _DebugPanelSize.compact,
        _DebugPanelSize.compact => _DebugPanelSize.expanded,
        _DebugPanelSize.expanded => _DebugPanelSize.collapsed,
      };
    });
  }

  void _setSize(_DebugPanelSize size) {
    setState(() => _size = size);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final frame = controller.latestFrame?.source;
    final noFrames = controller.framesReceived == 0;
    final labels = controller.latestDetectionLabels.isEmpty
        ? 'none'
        : controller.latestDetectionLabels.join(', ');
    final danger = widget.dangerDetection;
    final dangerLabels = danger?.latestDetections.isEmpty ?? true
        ? 'none'
        : danger!.latestDetections
              .map(
                (item) =>
                    '${item.kind.debugLabel} ${(item.confidence * 100).toStringAsFixed(0)}%'
                    '${item.ignoredReason == null ? "" : " ignored=${item.ignoredReason}"}'
                    '${item.cooldownBlocked ? " cooldown" : ""}',
              )
              .join(', ');

    final summaryLines = [
      controller.detectorStatus,
      'Nav frames: ${controller.framesReceived}  Risk: ${controller.assessment.highestRisk.name}',
      if (danger != null) 'Danger: ${danger.status}',
      if (danger != null)
        'Danger model: ${danger.modelReady ? "YES" : "NO"}  Runs: ${danger.dangerModelRuns}',
      if (danger != null) 'Danger detected: $dangerLabels',
    ];

    final detailLines = [
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
      if (danger != null) 'Danger: ${danger.status}',
      if (danger != null) danger.labelsStatus,
      if (danger != null)
        'Danger model loaded: ${danger.modelReady ? "YES" : "NO"}',
      if (danger != null) danger.tensorStatus,
      if (danger != null) 'Danger running: ${danger.isRunning ? "YES" : "NO"}',
      if (danger != null)
        'Danger in flight: ${danger.inferenceInFlight ? "YES" : "NO"}',
      if (danger != null) 'Danger runs: ${danger.dangerModelRuns}',
      if (danger != null) 'Danger hits: ${danger.dangerFramesWithDetections}',
      if (danger != null) 'Danger dropped ticks: ${danger.droppedTicks}',
      if (danger?.lastInferenceTime != null)
        'Danger inference: ${danger!.lastInferenceTime!.inMilliseconds} ms',
      if (danger != null) 'Danger detected: $dangerLabels',
      if (widget.enabled) 'Feedback: ${controller.cooldownStatus}',
      if (widget.enabled && danger != null)
        'Danger feedback: ${danger.alertStatus}',
      if (widget.enabled && controller.latestMessage.isNotEmpty)
        'Latest warning: ${controller.latestMessage}',
    ];

    if (_size == _DebugPanelSize.collapsed) {
      return _DebugPanelChrome(
        noFrames: noFrames,
        child: InkWell(
          onTap: _cycleSize,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  danger?.modelReady == true
                      ? Icons.shield_outlined
                      : Icons.warning_amber_rounded,
                  color: noFrames
                      ? AppColors.alertRed
                      : AppColors.electricGreen,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  danger?.modelReady == true ? 'DEBUG' : 'DANGER OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            maxWidth: _size == _DebugPanelSize.expanded ? 520 : 340,
            maxHeight: _size == _DebugPanelSize.expanded ? 430 : 190,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.detectorStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: noFrames
                            ? AppColors.alertRed
                            : AppColors.electricGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _PanelIconButton(
                    icon: _size == _DebugPanelSize.expanded
                        ? Icons.compress
                        : Icons.open_in_full,
                    label: _size == _DebugPanelSize.expanded
                        ? 'Compact debug panel'
                        : 'Expand debug panel',
                    onTap: () => _setSize(
                      _size == _DebugPanelSize.expanded
                          ? _DebugPanelSize.compact
                          : _DebugPanelSize.expanded,
                    ),
                  ),
                  _PanelIconButton(
                    icon: Icons.close_fullscreen,
                    label: 'Collapse debug panel',
                    onTap: () => _setSize(_DebugPanelSize.collapsed),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    (_size == _DebugPanelSize.expanded
                            ? detailLines
                            : summaryLines)
                        .join('\n'),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                button: true,
                label: widget.enabled
                    ? 'Hide detailed navigation diagnostics'
                    : 'Show detailed navigation diagnostics',
                child: GestureDetector(
                  onTap: widget.onToggle,
                  child: Text(
                    widget.enabled ? 'HIDE DETAILS' : 'SHOW DETAILS',
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

class _DebugPanelChrome extends StatelessWidget {
  const _DebugPanelChrome({required this.noFrames, required this.child});

  final bool noFrames;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: noFrames ? AppColors.alertRed : AppColors.electricGreen,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PanelIconButton extends StatelessWidget {
  const _PanelIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
      ),
    );
  }
}
