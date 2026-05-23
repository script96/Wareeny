import 'dart:ui';

enum OcrReadingMode { scan, read }

enum OcrLanguage { arabic, latin, mixed }

enum OcrFramingCue { none, noText, blurry, offCenter }

class OcrTextBlock {
  const OcrTextBlock({
    required this.text,
    required this.language,
    required this.confidence,
    required this.boundingBox,
    required this.isRTL,
  });

  final String text;
  final OcrLanguage language;
  final double confidence;
  final Rect boundingBox;
  final bool isRTL;
}

class OcrResult {
  const OcrResult({
    required this.blocks,
    required this.fullText,
    required this.primaryLanguage,
    required this.captureLatency,
  });

  final List<OcrTextBlock> blocks;
  final String fullText;
  final OcrLanguage primaryLanguage;
  final Duration captureLatency;

  bool get isEmpty => fullText.trim().isEmpty;
}
