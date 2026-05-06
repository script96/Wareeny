// OCR Service — text recognition using Google ML Kit (Latin/English).
//
// Arabic OCR is handled via Groq Vision in VisionService (not here).
//
// APIs:
//   extractText()       — ML Kit extraction for readText() TTS
//   extractStructured() — returns OCRResult with rawText + quality for QA
//   scanForDanger()     — background scan for danger/warning keywords

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'models/ocr_result.dart';

enum OCRLanguage { english, arabic }

class OCRService {
  final _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isDisposed = false;

  // English/Latin danger keywords found on warning signs.
  // Arabic signs are not detected here — ML Kit Latin doesn't support Arabic script.
  static const List<String> _dangerKeywords = [
    'wet floor', 'slippery floor', 'slippery',
    'danger', 'dangerous',
    'warning',
    'caution',
    'hazard', 'hazardous',
    'beware',
    'high voltage',
    'do not enter', 'no entry',
    'restricted area', 'keep out',
    'emergency',
    'fire hazard',
    'poison', 'toxic',
    'flammable',
    'no smoking',
    'explosive',
    'construction',
    'biohazard',
  ];

  // Word-boundary regex for each keyword. Avoids false positives like
  // "endangered" matching "danger" or "ranger" matching "danger".
  static final List<RegExp> _dangerPatterns = _dangerKeywords
      .map((k) => RegExp(r'\b' + k + r'\b', caseSensitive: false))
      .toList();

  Future<String> _extractRaw(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText result =
          await _latinRecognizer.processImage(inputImage);
      final text = result.text.trim();
      print('🔤 ML Kit result (${text.length} chars)');
      return text;
    } catch (e) {
      print('⚠️ ML Kit OCR error: $e');
      return '';
    }
  }

  /// Extract text from a camera snapshot. English only — Arabic is routed
  /// to GeminiService by VisionService before this is called.
  Future<String> extractText(XFile imageFile,
      {OCRLanguage language = OCRLanguage.english}) async {
    if (_isDisposed) return 'حدث خطأ، حاول مرة أخرى';

    final rawText = await _extractRaw(imageFile.path);

    if (rawText.isEmpty) return 'لا يوجد نص في الصورة';

    return _cleanText(rawText);
  }

  /// Extract text and return a structured OCRResult for QA use.
  /// English only — Arabic is routed to GeminiService by VisionService.
  Future<OCRResult> extractStructured(XFile imageFile,
      {OCRLanguage language = OCRLanguage.english}) async {
    if (_isDisposed) return OCRResult.fromRawText('', language);

    final rawText = await _extractRaw(imageFile.path);
    return OCRResult.fromRawText(rawText, language);
  }

  /// Scan [imagePath] for danger/warning keywords. Returns the first matched
  /// keyword (lowercase), or null if none found. Uses word-boundary matching
  /// to avoid false positives (e.g. "endangered" won't match "danger").
  Future<String?> scanForDanger(String imagePath) async {
    if (_isDisposed) return null;
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await _latinRecognizer.processImage(inputImage);
      final text = result.text;
      for (var i = 0; i < _dangerPatterns.length; i++) {
        if (_dangerPatterns[i].hasMatch(text)) {
          return _dangerKeywords[i];
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Danger scan error: $e');
      return null;
    }
  }

  String _cleanText(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 500) {
      cleaned = '${cleaned.substring(0, 500)}...';
    }
    return cleaned;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _latinRecognizer.close();
  }
}
