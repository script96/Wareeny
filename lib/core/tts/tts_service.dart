import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  var _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await _flutterTts.awaitSpeakCompletion(false);
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.52);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _isInitialized = true;
  }

  Future<void> speak(String text, {bool interrupt = true}) async {
    await initialize();

    if (interrupt) {
      await stop();
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
