import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:wareny/core/detection/detection_pipeline.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/target_labels.dart';
import 'package:wareny/core/di/app_scope.dart';
import 'package:wareny/core/di/service_registry.dart';
import 'package:wareny/core/theme/app_colors.dart';
import 'package:wareny/core/theme/app_spacing.dart';
import 'package:wareny/presentation/camera/camera_feed_view.dart';
import 'package:wareny/presentation/stuff_finder/target_selector_sheet.dart';
import 'package:wareny/shared/bridges/camera_bridge.dart';

class StuffFinderScreen extends StatefulWidget {
  const StuffFinderScreen({super.key});

  @override
  State<StuffFinderScreen> createState() => _StuffFinderScreenState();
}

class _StuffFinderScreenState extends State<StuffFinderScreen> {
  late ServiceRegistry _services;
  late DetectionPipeline _pipeline;
  var _didStart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStart) {
      return;
    }

    _services = AppScope.of(context);
    _pipeline = _services.detectionPipeline;
    _didStart = true;
    unawaited(_startStuffFinder());
  }

  @override
  void dispose() {
    if (_didStart) {
      _services.detectionFeedbackController.stop();
      _pipeline.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pipeline,
      builder: (context, _) {
        final currentTarget = _pipeline.currentTarget;

        return Stack(
          fit: StackFit.expand,
          children: [
            CameraFeedView(onImage: _handleCameraImage),
            if (currentTarget != null)
              CustomPaint(
                painter: _DetectionBoxPainter(detection: currentTarget),
              ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: 76,
              child: _TargetStatusBar(
                targetLabel: _pipeline.targetLabel,
                currentTarget: currentTarget,
                isDetectorReady: _pipeline.isReady,
                isDetectorLoading: _pipeline.isInitializing,
                detectorError: _pipeline.initializationError,
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: 112,
              child: Center(
                child: FloatingActionButton.extended(
                  heroTag: 'stuff-finder-target',
                  backgroundColor: AppColors.electricGreen,
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.search_outlined),
                  label: Text(
                    _pipeline.targetLabel == null
                        ? 'Select Target'
                        : 'Change Target',
                  ),
                  onPressed: _selectTarget,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startStuffFinder() async {
    try {
      _pipeline.start();
      _services.detectionFeedbackController.start();
      unawaited(_setNativeCameraMode());
    } catch (error, stackTrace) {
      if (_services.config.enableDiagnostics) {
        debugPrint('Stuff Finder failed to start: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _setNativeCameraMode() async {
    try {
      await _services.cameraBridge.setMode(CameraRuntimeMode.stuffFinder);
    } on MissingPluginException {
      if (_services.config.enableDiagnostics) {
        debugPrint('Camera bridge is not implemented on this platform yet.');
      }
    } on PlatformException catch (error) {
      if (_services.config.enableDiagnostics) {
        debugPrint('Camera bridge mode switch failed: ${error.message}');
      }
    }
  }

  void _handleCameraImage(CameraFrame frame) {
    unawaited(
      _pipeline.processFrame(
        frame.image,
        rotationDegrees: frame.rotationDegrees,
      ),
    );
  }

  Future<void> _selectTarget() async {
    final selected = await TargetSelectorSheet.show(
      context,
      options: TargetLabels.supportedStuffFinder,
      selectedLabel: _pipeline.targetLabel,
    );

    if (!mounted || selected == null) {
      return;
    }

    _pipeline.setTargetLabel(selected.label);
    try {
      await _pipeline.initialize();
    } catch (error, stackTrace) {
      if (_services.config.enableDiagnostics) {
        debugPrint('YOLO detector failed to initialize: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted && MediaQuery.supportsAnnounceOf(context)) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Object detector unavailable',
          TextDirection.ltr,
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Finding ${selected.displayName}',
        TextDirection.ltr,
      );
    }
  }
}

class _TargetStatusBar extends StatelessWidget {
  const _TargetStatusBar({
    required this.targetLabel,
    required this.currentTarget,
    required this.isDetectorReady,
    required this.isDetectorLoading,
    required this.detectorError,
  });

  final String? targetLabel;
  final DetectionResult? currentTarget;
  final bool isDetectorReady;
  final bool isDetectorLoading;
  final Object? detectorError;

  @override
  Widget build(BuildContext context) {
    final selectedName = targetLabel == null
        ? 'No target selected'
        : TargetLabels.stuffFinderDisplayNameFor(targetLabel!);
    final confidence = currentTarget == null
        ? null
        : '${(currentTarget!.confidence * 100).round()}%';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(
                _directionIcon(currentTarget?.direction),
                color: AppColors.electricGreen,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText(currentTarget),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (confidence != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  confidence,
                  style: const TextStyle(
                    color: AppColors.electricGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _directionIcon(ObjectDirection? direction) {
    return switch (direction) {
      ObjectDirection.left => Icons.arrow_back_rounded,
      ObjectDirection.center => Icons.center_focus_strong_rounded,
      ObjectDirection.right => Icons.arrow_forward_rounded,
      null => Icons.search_rounded,
    };
  }

  String _statusText(DetectionResult? target) {
    if (targetLabel == null) {
      return 'Select an object';
    }
    if (isDetectorLoading) {
      return 'Loading object detector';
    }
    if (detectorError != null) {
      return 'Object detector unavailable';
    }
    if (!isDetectorReady) {
      return 'Waiting for detector';
    }
    if (target == null) {
      return 'Searching';
    }

    final direction = switch (target.direction) {
      ObjectDirection.left => 'Left',
      ObjectDirection.center => 'Center',
      ObjectDirection.right => 'Right',
    };
    final proximity = switch (target.proximity) {
      ObjectProximity.near => 'Near',
      ObjectProximity.mid => 'Mid',
      ObjectProximity.far => 'Far',
    };

    return '$direction - $proximity';
  }
}

class _DetectionBoxPainter extends CustomPainter {
  const _DetectionBoxPainter({required this.detection});

  final DetectionResult detection;

  @override
  void paint(Canvas canvas, Size size) {
    final box = detection.boundingBox;
    final frameSize = detection.frameSize;
    final destination = frameSize == null
        ? Offset.zero & size
        : Alignment.center.inscribe(
            applyBoxFit(BoxFit.cover, frameSize, size).destination,
            Offset.zero & size,
          );
    final rect = Rect.fromLTRB(
      destination.left + box.left * destination.width,
      destination.top + box.top * destination.height,
      destination.left + box.right * destination.width,
      destination.top + box.bottom * destination.height,
    );
    final paint = Paint()
      ..color = AppColors.electricGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()
      ..color = AppColors.electricGreen.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _DetectionBoxPainter oldDelegate) {
    return oldDelegate.detection != detection;
  }
}
