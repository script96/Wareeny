import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceRecognitionResult {
  const VoiceRecognitionResult({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

class VoiceRecognitionError {
  const VoiceRecognitionError({required this.code, required this.isPermanent});

  final String code;
  final bool isPermanent;
}

abstract interface class VoiceCommandService {
  bool get isListening;

  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(VoiceRecognitionError error) onError,
  });

  Future<List<String>> localeIds();

  Future<void> listen({
    required String? localeId,
    required void Function(VoiceRecognitionResult result) onResult,
    required void Function(double level) onSoundLevel,
    required Duration listenFor,
    required Duration pauseFor,
    ListenMode listenMode = ListenMode.confirmation,
  });

  Future<void> stop();

  Future<void> cancel();
}

class SpeechToTextVoiceCommandService implements VoiceCommandService {
  SpeechToTextVoiceCommandService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(VoiceRecognitionError error) onError,
  }) {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError error) {
        onError(
          VoiceRecognitionError(
            code: error.errorMsg,
            isPermanent: error.permanent,
          ),
        );
      },
    );
  }

  @override
  Future<List<String>> localeIds() async {
    final locales = await _speech.locales();
    return locales.map((locale) => locale.localeId).toList(growable: false);
  }

  @override
  Future<void> listen({
    required String? localeId,
    required void Function(VoiceRecognitionResult result) onResult,
    required void Function(double level) onSoundLevel,
    required Duration listenFor,
    required Duration pauseFor,
    ListenMode listenMode = ListenMode.confirmation,
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(
          VoiceRecognitionResult(
            text: result.recognizedWords,
            isFinal: result.finalResult,
          ),
        );
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: listenMode,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
