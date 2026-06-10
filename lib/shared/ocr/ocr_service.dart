import 'package:wareeny/shared/ocr/ocr_models.dart';

class OcrService {
  List<String> chunkForTts(String text, {int maxLength = 200}) {
    if (text.trim().isEmpty) return [];
    final sentences = text.split(RegExp(r'(?<=[.!?؟،])\s+'));
    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final sentence in sentences) {
      if (buffer.length + sentence.length > maxLength && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      buffer.write('$sentence ');
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks.where((c) => c.isNotEmpty).toList();
  }

  OcrFramingCue framingCue(OcrResult result) {
    if (result.isEmpty) return OcrFramingCue.noText;
    if (result.blocks.isEmpty) return OcrFramingCue.noText;

    final avgConfidence = result.blocks
            .map((b) => b.confidence)
            .fold(0.0, (a, b) => a + b) /
        result.blocks.length;

    // ML Kit often returns null confidence (maps to 0.0) — only flag blurry
    // when we have real signal (> 0) and it's below threshold.
    if (avgConfidence > 0.0 && avgConfidence < 0.45) {
      return OcrFramingCue.blurry;
    }

    return OcrFramingCue.none;
  }

  OcrResult processResult(OcrResult result) {
    final filtered = _filterBlocks(result.blocks);
    final raw = filtered.map((b) => b.text).join('\n').trim();
    final cleaned = _cleanText(raw);
    return OcrResult(
      blocks: filtered,
      fullText: cleaned,
      primaryLanguage: result.primaryLanguage,
      captureLatency: result.captureLatency,
    );
  }

  List<OcrTextBlock> _filterBlocks(List<OcrTextBlock> blocks) {
    final seen = <String>{};
    return blocks.where((block) {
      final normalized = block.text.toLowerCase().trim();
      if (normalized.isEmpty) return false;
      if (!seen.add(normalized)) return false;

      final chars = block.text.replaceAll(' ', '');
      if (chars.isEmpty) return false;
      final validCount = chars.codeUnits.where((c) =>
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        (c >= 0x0600 && c <= 0x06FF)
      ).length;
      return (1.0 - validCount / chars.length) <= 0.5;
    }).toList();
  }

  String _cleanText(String text) {
    return text
      .replaceAll(RegExp(r'(?:^|(?<=\s))[#|©®™°~^\\/]+(?=\s|$)', multiLine: true), '')
      .replaceAll(RegExp(r'[-=_]{3,}'), '')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
  }

  String framingMessage(OcrFramingCue cue) => switch (cue) {
        OcrFramingCue.noText => 'No text detected. Move the camera closer.',
        OcrFramingCue.blurry => 'Text is blurry. Hold steady.',
        OcrFramingCue.offCenter => 'Center the text in the frame.',
        OcrFramingCue.none => '',
      };
}
