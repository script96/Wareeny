import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';

class ScanResultView extends StatefulWidget {
  const ScanResultView({required this.text, super.key});

  final String text;

  @override
  State<ScanResultView> createState() => _ScanResultViewState();
}

class _ScanResultViewState extends State<ScanResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.electricGreen, width: 1),
            ),
            child: Text(
              widget.text,
              textDirection: _isArabic(widget.text)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isArabic(String text) {
    final arabicCount = text.codeUnits
        .where((c) => c >= 0x0600 && c <= 0x06FF)
        .length;
    return arabicCount > text.length * 0.3;
  }
}
