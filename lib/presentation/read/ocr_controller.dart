import 'package:flutter/foundation.dart';

import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/bridges/ocr_bridge.dart';
import 'package:wareeny/shared/ocr/ocr_models.dart';
import 'package:wareeny/shared/ocr/ocr_service.dart';

class OcrController extends ChangeNotifier {
  OcrController({
    required OcrBridge ocrBridge,
    required AudioHapticsBridge audioHapticsBridge,
  }) : _ocr = ocrBridge,
       _audioHaptics = audioHapticsBridge,
       _service = OcrService();

  final OcrBridge _ocr;
  final AudioHapticsBridge _audioHaptics;
  final OcrService _service;

  OcrReadingMode subMode = OcrReadingMode.document;
  bool isCapturing = false;
  OcrResult? lastResult;
  OcrFramingCue framingCue = OcrFramingCue.none;

  bool _readingActive = false;
  List<String> _chunks = [];
  int _chunkIndex = 0;

  bool get isReadingActive => _readingActive;

  // Centralized TTS is configured inside AudioHapticsBridge

  void cycleSubMode() {
    cancelReading();
    final modes = OcrReadingMode.values;
    final nextIndex = (modes.indexOf(subMode) + 1) % modes.length;
    subMode = modes[nextIndex];
    notifyListeners();
  }

  void cycleSubModePrevious() {
    cancelReading();
    final modes = OcrReadingMode.values;
    final prevIndex = (modes.indexOf(subMode) - 1 + modes.length) % modes.length;
    subMode = modes[prevIndex];
    notifyListeners();
  }

  void setSubMode(OcrReadingMode mode) {
    if (subMode == mode) return;
    cancelReading();
    subMode = mode;
    notifyListeners();
  }

  Future<void> scan(String imagePath) async {
    if (isCapturing) return;
    isCapturing = true;
    framingCue = OcrFramingCue.none;
    notifyListeners();

    try {
      final raw = await _ocr.recognizeFromFile(imagePath);
      final result = _service.processResult(raw);
      lastResult = result;
      final cue = _service.framingCue(result);
      framingCue = cue;

      if (cue != OcrFramingCue.none) {
        await _speak(_service.framingMessage(cue), OcrLanguage.latin);
      } else if (result.isEmpty) {
        await _speak('No text found.', OcrLanguage.latin);
      } else {
        debugPrint(
          'OCR latency: ${result.captureLatency.inMilliseconds}ms '
          'chars: ${result.fullText.length}',
        );
        await _speak(result.fullText, result.primaryLanguage);
      }
    } finally {
      isCapturing = false;
      notifyListeners();
    }
  }

  Future<void> startReading(String imagePath) async {
    if (isCapturing) return;
    isCapturing = true;
    notifyListeners();

    try {
      final raw = await _ocr.recognizeFromFile(imagePath);
      final result = _service.processResult(raw);
      lastResult = result;
      final cue = _service.framingCue(result);
      framingCue = cue;

      if (cue != OcrFramingCue.none) {
        await _speak(_service.framingMessage(cue), OcrLanguage.latin);
        return;
      }

      if (result.isEmpty) {
        await _speak(
          'No text found. Aim at a document and try again.',
          OcrLanguage.latin,
        );
        return;
      }

      debugPrint(
        'OCR latency: ${result.captureLatency.inMilliseconds}ms '
        'chars: ${result.fullText.length}',
      );

      _chunks = _service.chunkForTts(result.fullText);
      _chunkIndex = 0;
      _readingActive = true;
      notifyListeners();
      await _speakChunk();
    } finally {
      isCapturing = false;
      notifyListeners();
    }
  }

  void stopReading() {
    _audioHaptics.stopSpeech();
    _readingActive = false;
    notifyListeners();
  }

  void repeatChunk() {
    if (_chunks.isEmpty) return;
    _audioHaptics.stopSpeech();
    _speakChunk();
  }

  void skipChunk() {
    _audioHaptics.stopSpeech();
    if (_chunkIndex + 1 < _chunks.length) {
      _chunkIndex++;
      notifyListeners();
      _speakChunk();
    } else {
      _finishReading();
    }
  }

  void cancelReading() {
    _audioHaptics.stopSpeech();
    _readingActive = false;
    _chunks = [];
    _chunkIndex = 0;
    lastResult = null;
    framingCue = OcrFramingCue.none;
    notifyListeners();
  }

  void _onChunkComplete() {
    if (!_readingActive) return;
    _chunkIndex++;
    notifyListeners();
    if (_chunkIndex < _chunks.length) {
      _speakChunk();
    } else {
      _finishReading();
    }
  }

  Future<void> _speakChunk() async {
    if (_chunkIndex >= _chunks.length) return;
    await _speak(
      _chunks[_chunkIndex],
      lastResult?.primaryLanguage ?? OcrLanguage.latin,
    );
  }

  Future<void> _speak(String text, OcrLanguage language) async {
    final lang = language == OcrLanguage.arabic ? 'ar-EG' : 'en-US';
    await _audioHaptics.speak(
      text,
      languageCode: lang,
      speechRate: 0.5,
      onComplete: _onChunkComplete,
    );
  }

  void _finishReading() {
    _readingActive = false;
    _chunks = [];
    _chunkIndex = 0;
    _speak('Reading complete.', OcrLanguage.latin);
    notifyListeners();
  }

  @override
  void dispose() {
    _audioHaptics.stopSpeech();
    super.dispose();
  }
}
