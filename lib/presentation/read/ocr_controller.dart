import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/bridges/ocr_bridge.dart';
import 'package:wareeny/shared/ocr/ocr_models.dart';
import 'package:wareeny/shared/ocr/ocr_service.dart';

class OcrController extends ChangeNotifier {
  OcrController({
    required OcrBridge ocrBridge,
    required AudioHapticsBridge audioHapticsBridge,
  })  : _ocr = ocrBridge,
        _audio = audioHapticsBridge,
        _service = OcrService();

  final OcrBridge _ocr;
  final AudioHapticsBridge _audio;
  final OcrService _service;

  OcrReadingMode subMode = OcrReadingMode.scan;
  bool isCapturing = false;
  OcrResult? lastResult;
  OcrFramingCue framingCue = OcrFramingCue.none;

  bool _readingActive = false;
  List<String> _chunks = [];
  int _chunkIndex = 0;
  Timer? _chunkTimer;

  bool get isReadingActive => _readingActive;
  String? get activeChunk =>
      _chunkIndex < _chunks.length ? _chunks[_chunkIndex] : null;

  void toggleSubMode() {
    cancelReading();
    subMode = subMode == OcrReadingMode.scan
        ? OcrReadingMode.read
        : OcrReadingMode.scan;
    notifyListeners();
  }

  Future<void> scan(String imagePath, Size frameSize) async {
    if (isCapturing) return;
    isCapturing = true;
    framingCue = OcrFramingCue.none;
    notifyListeners();

    try {
      final result = await _ocr.recognizeFromFile(imagePath);
      lastResult = result;
      final cue = _service.framingCue(result, frameSize);
      framingCue = cue;

      if (cue != OcrFramingCue.none) {
        await _audio.speak(_service.framingMessage(cue));
      } else if (result.isEmpty) {
        await _audio.speak('No text found.');
      } else {
        debugPrint('OCR latency: ${result.captureLatency.inMilliseconds}ms '
            'chars: ${result.fullText.length}');
        await _audio.speak(result.fullText);
      }
    } finally {
      isCapturing = false;
      notifyListeners();
    }
  }

  Future<void> startReading(String imagePath, Size frameSize) async {
    if (isCapturing) return;
    isCapturing = true;
    notifyListeners();

    try {
      final result = await _ocr.recognizeFromFile(imagePath);
      lastResult = result;
      final cue = _service.framingCue(result, frameSize);
      framingCue = cue;

      if (cue != OcrFramingCue.none) {
        await _audio.speak(_service.framingMessage(cue));
        return;
      }

      if (result.isEmpty) {
        await _audio.speak('No text found. Aim at a document and try again.');
        return;
      }

      debugPrint('OCR latency: ${result.captureLatency.inMilliseconds}ms '
          'chars: ${result.fullText.length}');

      _chunks = _service.chunkForTts(result.fullText);
      _chunkIndex = 0;
      _readingActive = true;
      notifyListeners();
      _speakNextChunk();
    } finally {
      isCapturing = false;
      notifyListeners();
    }
  }

  void stopReading() {
    _chunkTimer?.cancel();
    _audio.stopSpeech();
    _readingActive = false;
    notifyListeners();
  }

  void resumeReading() {
    if (!_readingActive || _chunks.isEmpty) return;
    _speakNextChunk();
  }

  void repeatChunk() {
    _chunkTimer?.cancel();
    if (_chunks.isEmpty) return;
    _audio.speak(_chunks[_chunkIndex]);
    _scheduleNext(_chunks[_chunkIndex]);
  }

  void skipChunk() {
    _chunkTimer?.cancel();
    if (_chunkIndex + 1 < _chunks.length) {
      _chunkIndex++;
      notifyListeners();
      _speakNextChunk();
    } else {
      _finishReading();
    }
  }

  void cancelReading() {
    _chunkTimer?.cancel();
    _audio.stopSpeech();
    _readingActive = false;
    _chunks = [];
    _chunkIndex = 0;
    lastResult = null;
    framingCue = OcrFramingCue.none;
    notifyListeners();
  }

  void _speakNextChunk() {
    if (_chunkIndex >= _chunks.length) {
      _finishReading();
      return;
    }
    final chunk = _chunks[_chunkIndex];
    _audio.speak(chunk, interrupt: true);
    _scheduleNext(chunk);
  }

  void _scheduleNext(String chunk) {
    // Estimate TTS duration: ~10 chars/sec, minimum 2 seconds
    final ms = (chunk.length * 100).clamp(2000, 15000);
    _chunkTimer = Timer(Duration(milliseconds: ms), () {
      if (!_readingActive) return;
      _chunkIndex++;
      notifyListeners();
      _speakNextChunk();
    });
  }

  void _finishReading() {
    _readingActive = false;
    _chunks = [];
    _chunkIndex = 0;
    _audio.speak('Reading complete.');
    notifyListeners();
  }

  @override
  void dispose() {
    _chunkTimer?.cancel();
    super.dispose();
  }
}
