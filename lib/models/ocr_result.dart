// OCR Result model — structured output from OCR for both TTS and QA use.
//
// rawText:       full cleaned text with paragraph breaks preserved (for QA context).
// spokenPreview: short TTS-safe summary (≤200 chars, whitespace collapsed).
// quality:       empty / tooShort / valid — used to gate QA entry.

import '../ocr_service.dart';

/// Quality assessment of OCR output.
enum OCRQuality {
  /// No text recognized at all.
  empty,

  /// Some text but likely noise or partial capture (<20 chars).
  tooShort,

  /// Sufficient text for QA context.
  valid,
}

class OCRResult {
  final String rawText;
  final String spokenPreview;
  final OCRLanguage language;
  final int charCount;
  final OCRQuality quality;

  const OCRResult({
    required this.rawText,
    required this.spokenPreview,
    required this.language,
    required this.charCount,
    required this.quality,
  });

  bool get isEmpty => quality == OCRQuality.empty;

  /// Build an OCRResult from raw OCR engine output.
  factory OCRResult.fromRawText(String raw, OCRLanguage language) {
    final qaText = cleanForQa(raw);
    final preview = cleanForTts(raw);
    final quality = assessQuality(qaText);

    return OCRResult(
      rawText: qaText,
      spokenPreview: preview,
      language: language,
      charCount: qaText.length,
      quality: quality,
    );
  }

  /// Clean text for QA context: collapse excessive whitespace but
  /// preserve meaningful paragraph breaks (\n).
  static String cleanForQa(String raw) {
    // Replace \r\n with \n, then collapse multiple consecutive \n to max 2
    String cleaned = raw.replaceAll('\r\n', '\n');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Collapse horizontal whitespace (spaces/tabs) within lines
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Trim each line
    cleaned = cleaned
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');

    return cleaned.trim();
  }

  /// Clean text for TTS: collapse all whitespace, truncate to 200 chars.
  static String cleanForTts(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length > 200) {
      // Cut at last space before 200 chars to avoid mid-word truncation
      final cutPoint = cleaned.lastIndexOf(' ', 200);
      final end = cutPoint > 100 ? cutPoint : 200;
      cleaned = '${cleaned.substring(0, end)}...';
    }

    return cleaned;
  }

  /// Assess quality of cleaned OCR text.
  static OCRQuality assessQuality(String text) {
    if (text.isEmpty) return OCRQuality.empty;
    if (text.length < 20) return OCRQuality.tooShort;
    return OCRQuality.valid;
  }

  @override
  String toString() =>
      'OCRResult(quality: ${quality.name}, chars: $charCount, lang: ${language.name})';
}
