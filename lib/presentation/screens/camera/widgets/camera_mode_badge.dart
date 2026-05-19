import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

class CameraModeBadge extends StatefulWidget {
  final String text;
  final Color color;
  final bool isPulsing;

  const CameraModeBadge({
    super.key,
    required this.text,
    required this.color,
    required this.isPulsing,
  });

  @override
  State<CameraModeBadge> createState() => _CameraModeBadgeState();
}

class _CameraModeBadgeState extends State<CameraModeBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CameraModeBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPulsing != widget.isPulsing) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (!widget.isPulsing) {
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
      _opacity = null;
      return;
    }

    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(
      begin: 0.6,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
    _controller!.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.color.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(widget.text, style: AppTextStyles.badgeText),
    );

    if (_opacity == null || _controller == null) {
      return badge;
    }

    return AnimatedBuilder(
      animation: _opacity!,
      builder: (context, child) {
        return Opacity(opacity: _opacity!.value, child: badge);
      },
    );
  }
}
