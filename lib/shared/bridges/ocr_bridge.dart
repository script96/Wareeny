import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:wareeny/shared/ocr/ocr_models.dart';

class OcrBridge {
  OcrBridge()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<OcrResult> recognizeFromFile(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);
    stopwatch.stop();

    final blocks = recognized.blocks.map(_mapBlock).toList()
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final fullText = blocks.map((b) => b.text).join('\n').trim();

    return OcrResult(
      blocks: blocks,
      fullText: _normalizeArabic(fullText),
      primaryLanguage: _detectLanguage(fullText),
      captureLatency: stopwatch.elapsed,
    );
  }

  void dispose() => _recognizer.close();

  OcrTextBlock _mapBlock(TextBlock block) {
    final text = block.lines.map((l) => l.text).join(' ');
    final confidence = block.lines.isEmpty
        ? 0.0
        : block.lines
                .map((l) => l.elements.isEmpty
                    ? 0.0
                    : l.elements.fold(0.0, (sum, e) => sum + (e.confidence ?? 0.0)) /
                        l.elements.length)
                .fold(0.0, (a, b) => a + b) /
            block.lines.length;

    final lang = _detectLanguage(text);
    final rect = block.boundingBox;
    final boundingBox = rect != null
        ? Rect.fromLTRB(
            rect.left.toDouble(),
            rect.top.toDouble(),
            rect.right.toDouble(),
            rect.bottom.toDouble(),
          )
        : Rect.zero;

    return OcrTextBlock(
      text: text,
      language: lang,
      confidence: confidence,
      boundingBox: boundingBox,
      isRTL: lang == OcrLanguage.arabic,
    );
  }

  OcrLanguage _detectLanguage(String text) {
    if (text.isEmpty) return OcrLanguage.latin;
    final chars = text.replaceAll(RegExp(r'\s'), '');
    if (chars.isEmpty) return OcrLanguage.latin;
    final arabicCount =
        chars.codeUnits.where((c) => c >= 0x0600 && c <= 0x06FF).length;
    final ratio = arabicCount / chars.length;
    if (ratio > 0.6) return OcrLanguage.arabic;
    if (ratio > 0.2) return OcrLanguage.mixed;
    return OcrLanguage.latin;
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll('ـ', '')
        .replaceAll(RegExp('[أإآ]'), 'ا');
  }
}
