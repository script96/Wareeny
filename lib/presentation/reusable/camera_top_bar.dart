import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareny/core/theme/app_colors.dart';
import 'package:wareny/core/theme/app_spacing.dart';
import 'package:wareny/presentation/navigation/app_mode.dart';
import 'package:wareny/presentation/reusable/live_indicator.dart';

/// Glassmorphism top bar showing the brand name, live indicator, and current mode icon.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({required this.currentMode, super.key});

  final AppMode currentMode;

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
            children: [
              _BrandLabel(),
              const Spacer(),
              const LiveIndicator(),
              const Spacer(),
              _ModeIconBadge(mode: currentMode),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'WARE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          TextSpan(
            text: 'ENY',
            style: TextStyle(
              color: AppColors.electricGreen,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeIconBadge extends StatelessWidget {
  const _ModeIconBadge({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: AppColors.electricGreenDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.electricGreen, width: 1),
      ),
      child: Icon(mode.icon, color: AppColors.electricGreen, size: 18),
    );
  }
}
