import 'dart:ui';

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

  OcrFramingCue framingCue(OcrResult result, Size frameSize) {
    if (result.isEmpty) return OcrFramingCue.noText;
    if (result.blocks.isEmpty) return OcrFramingCue.noText;

    final avgConfidence = result.blocks
            .map((b) => b.confidence)
            .fold(0.0, (a, b) => a + b) /
        result.blocks.length;

    if (avgConfidence < 0.45) return OcrFramingCue.blurry;

    final largest = result.blocks.reduce((a, b) {
      final aArea = a.boundingBox.width * a.boundingBox.height;
      final bArea = b.boundingBox.width * b.boundingBox.height;
      return aArea > bArea ? a : b;
    });

    final blockCx = largest.boundingBox.center.dx;
    final blockCy = largest.boundingBox.center.dy;
    final threshX = frameSize.width * 0.25;
    final threshY = frameSize.height * 0.25;

    if ((blockCx - frameSize.width / 2).abs() > threshX ||
        (blockCy - frameSize.height / 2).abs() > threshY) {
      return OcrFramingCue.offCenter;
    }

    return OcrFramingCue.none;
  }

  String framingMessage(OcrFramingCue cue) => switch (cue) {
        OcrFramingCue.noText => 'No text detected. Move the camera closer.',
        OcrFramingCue.blurry => 'Text is blurry. Hold steady.',
        OcrFramingCue.offCenter => 'Center the text in the frame.',
        OcrFramingCue.none => '',
      };
}
