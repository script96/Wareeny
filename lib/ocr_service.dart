// OCR Service — Separate English and Arabic text recognition
//
// English mode: Google ML Kit (fast, accurate for Latin scripts + numbers)
// Arabic mode: Tesseract OCR with ara.traineddata (offline Arabic support)
//
// User selects which mode to use — no mixing.

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

enum OCRLanguage { english, arabic }

class OCRService {
  final _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isDisposed = false;

  /// Extract text from a camera snapshot using the specified language engine.
  Future<String> extractText(XFile imageFile, {OCRLanguage language = OCRLanguage.english}) async {
    if (_isDisposed) return 'حدث خطأ، حاول مرة أخرى';

    final imagePath = imageFile.path;

    String rawText = '';

    if (language == OCRLanguage.english) {
      // ── ML Kit (English + numbers) ──
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final RecognizedText result =
            await _latinRecognizer.processImage(inputImage);
        rawText = result.text.trim();
        print('🔤 ML Kit result (${rawText.length} chars)');
      } catch (e) {
        print('⚠️ ML Kit OCR error: $e');
      }
    } else {
      // ── Tesseract (Arabic) ──
      try {
        rawText = await TesseractOcr.extractText(
          imagePath,
          config: const OCRConfig(
            language: 'ara',
            engine: OCREngine.tesseract,
          ),
        );
        rawText = rawText.trim();
        print('🔠 Tesseract result (${rawText.length} chars)');
      } catch (e) {
        print('⚠️ Tesseract OCR error: $e');
      }
    }

    if (rawText.isEmpty) {
      return 'لا يوجد نص في الصورة';
    }

    return _cleanText(rawText);
  }

  /// Clean up recognized text for TTS delivery.
  String _cleanText(String raw) {
    // Remove excessive whitespace
    String cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Limit length — very long text overwhelms the user
    if (cleaned.length > 500) {
      cleaned = '${cleaned.substring(0, 500)}...';
    }

    return cleaned;
  }

  /// Release ML Kit resources. Must be called in widget dispose().
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _latinRecognizer.close();
  }
}
