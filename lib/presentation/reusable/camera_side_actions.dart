import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';

/// Vertical column of glassmorphism icon action buttons on the camera's right edge.
class CameraSideActions extends StatelessWidget {
  const CameraSideActions({this.onAsk, this.askLabel, super.key});

  /// When set, shows an "Ask a question" (QA) button that triggers this.
  final VoidCallback? onAsk;

  /// Accessible label / tooltip for the Ask button.
  final String? askLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onAsk != null) ...[
          _GlassIconButton(
            icon: Icons.mic_none_rounded,
            tooltip: askLabel ?? 'Ask a question',
            onTap: onAsk!,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _GlassIconButton(
          icon: Icons.flashlight_on_outlined,
          tooltip: 'Flash',
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        _GlassIconButton(
          icon: Icons.photo_camera_outlined,
          tooltip: 'Capture',
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        _GlassIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: 'Info',
          onTap: () {},
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.glassWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
