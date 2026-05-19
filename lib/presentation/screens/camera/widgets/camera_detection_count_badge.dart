import 'package:flutter/material.dart';

import '../../../../detector.dart';
import '../../../theme/app_text_styles.dart';

class CameraDetectionCountBadge extends StatelessWidget {
  final Stream<List<Detection>> detectionStream;
  final bool isVisible;

  const CameraDetectionCountBadge({
    super.key,
    required this.detectionStream,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Detection>>(
      stream: detectionStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 48,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(180),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${snapshot.data!.length}',
              style: AppTextStyles.badgeText,
            ),
          ),
        );
      },
    );
  }
}
