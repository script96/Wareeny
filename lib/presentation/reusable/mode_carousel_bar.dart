import 'package:flutter/material.dart';

import 'package:wareny/core/theme/app_spacing.dart';
import 'package:wareny/presentation/navigation/app_mode.dart';

class ModeCarouselBar extends StatelessWidget {
  const ModeCarouselBar({
    required this.previous,
    required this.current,
    required this.next,
    super.key,
  });

  final AppMode previous;
  final AppMode current;
  final AppMode next;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Current mode ${current.label}. Previous ${previous.label}. Next ${next.label}.',
      hint:
          'Swipe with two fingers left or right on the camera feed to change mode.',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeLabel(mode: previous),
            _CurrentModeLabel(mode: current),
            _ModeLabel(mode: next),
          ],
        ),
      ),
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Text(
        mode.label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CurrentModeLabel extends StatelessWidget {
  const _CurrentModeLabel({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        mode.label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFFFFD600),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
