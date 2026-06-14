import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';

/// Vertical column of glassmorphism icon action buttons on the camera's right edge.
class CameraSideActions extends StatelessWidget {
  const CameraSideActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlassIconButton(
          icon: Icons.flashlight_on_outlined,
          tooltip: l10n.flash,
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        _GlassIconButton(
          icon: Icons.photo_camera_outlined,
          tooltip: l10n.capture,
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        _GlassIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: l10n.info,
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

  /// Minimum accessible touch target (logical pixels), per WCAG/Material a11y.
  static const double _minTouchTarget = 48;

  /// Visible diameter of the glass circle.
  static const double _visualSize = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          // Opaque so the full 48x48 area is tappable, not just the 44 circle.
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: SizedBox(
            width: _minTouchTarget,
            height: _minTouchTarget,
            child: Center(
              child: AnimatedScale(
                scale: _pressed ? 0.88 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: _visualSize,
                      height: _visualSize,
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.glassBorder, width: 1),
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
        ),
      ),
    );
  }
}
