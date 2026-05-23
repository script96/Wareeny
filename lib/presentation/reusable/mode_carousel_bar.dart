import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';

/// Redesigned glassmorphism mode selector bar.
///
/// Shows previous and next modes as dimmed icon+label chips,
/// and the current mode as a glowing highlighted pill.
class ModeCarouselBar extends StatelessWidget {
  const ModeCarouselBar({
    required this.previous,
    required this.current,
    required this.next,
    this.onPreviousTap,
    this.onNextTap,
    super.key,
  });

  final AppMode previous;
  final AppMode current;
  final AppMode next;
  final VoidCallback? onPreviousTap;
  final VoidCallback? onNextTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Current mode ${current.label}. Previous ${previous.label}. Next ${next.label}.',
      hint: 'Tap left or right pill to switch modes.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SideModePill(mode: previous, onTap: onPreviousTap),
                const SizedBox(width: AppSpacing.xs),
                _ActiveModePill(mode: current),
                const SizedBox(width: AppSpacing.xs),
                _SideModePill(mode: next, onTap: onNextTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideModePill extends StatelessWidget {
  const _SideModePill({required this.mode, this.onTap});

  final AppMode mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap != null ? 'Switch to ${mode.label}' : mode.label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode.icon,
                color: onTap != null ? Colors.white60 : Colors.white38,
                size: 18,
              ),
              const SizedBox(height: 3),
              Text(
                mode.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onTap != null ? Colors.white60 : Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveModePill extends StatelessWidget {
  const _ActiveModePill({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.electricGreenDim,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.electricGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricGreen.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, color: AppColors.electricGreen, size: 22),
          const SizedBox(height: 4),
          Text(
            mode.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.electricGreen,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
