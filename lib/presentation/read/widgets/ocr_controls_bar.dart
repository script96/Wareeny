import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';

class OcrControlsBar extends StatelessWidget {
  const OcrControlsBar({
    required this.onStop,
    required this.onRepeat,
    required this.onSkip,
    required this.onCancel,
    super.key,
  });

  final VoidCallback onStop;
  final VoidCallback onRepeat;
  final VoidCallback onSkip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
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
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: Icons.stop_rounded,
                label: 'Stop',
                onTap: onStop,
              ),
              _ControlButton(
                icon: Icons.replay_rounded,
                label: 'Repeat',
                onTap: onRepeat,
              ),
              _ControlButton(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                onTap: onSkip,
              ),
              _ControlButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onTap: onCancel,
                tint: AppColors.alertRed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
