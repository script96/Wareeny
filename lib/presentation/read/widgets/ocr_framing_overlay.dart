import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/shared/ocr/ocr_models.dart';

class OcrFramingOverlay extends StatefulWidget {
  const OcrFramingOverlay({required this.cue, super.key});

  final OcrFramingCue cue;

  @override
  State<OcrFramingOverlay> createState() => _OcrFramingOverlayState();
}

class _OcrFramingOverlayState extends State<OcrFramingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cue == OcrFramingCue.none) return const SizedBox.shrink();

    return Center(
      child: FadeTransition(
        opacity: _blink,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.cue == OcrFramingCue.noText
                  ? AppColors.glassBorder
                  : AppColors.signalAmber,
              width: 1.5,
            ),
          ),
          child: Text(
            _label(widget.cue),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _label(OcrFramingCue cue) => switch (cue) {
        OcrFramingCue.noText => 'No text detected\nMove closer',
        OcrFramingCue.blurry => 'Hold steady',
        OcrFramingCue.offCenter => 'Center the text',
        OcrFramingCue.none => '',
      };
}
