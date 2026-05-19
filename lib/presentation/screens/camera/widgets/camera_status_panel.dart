import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

class CameraStatusPanel extends StatelessWidget {
  final String statusText;

  const CameraStatusPanel({super.key, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          statusText,
          textAlign: TextAlign.center,
          style: AppTextStyles.statusText,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
