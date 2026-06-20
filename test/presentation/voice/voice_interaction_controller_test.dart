import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_items.dart';
import 'package:wareeny/presentation/voice/voice_command_service.dart';
import 'package:wareeny/presentation/voice/voice_interaction_controller.dart';

void main() {
  test('prefers ar-EG and fires one mode command per utterance', () async {
    final speech = _FakeVoiceCommandService(
      locales: ['en_US', 'ar_SA', 'ar_EG'],
    );
    final feedback = _FakeVoiceFeedback();
    final controller = VoiceInteractionController(
      speech,
      feedback,
      modeTransitionDelay: Duration.zero,
    );
    final selectedModes = <AppMode>[];
    controller.bindModeSelection(selectedModes.add);

    await controller.triggerModeListening();
    expect(speech.selectedLocale, 'ar_EG');
    expect(controller.state, VoiceInteractionState.listening);

    speech.emit('ممكن افتح وضع التنقل', isFinal: true);
    speech.emit('ممكن افتح وضع التنقل', isFinal: true);
    await _flushAsync();

    expect(selectedModes, [AppMode.navigation]);
    expect(feedback.spoken, ['اتكلم', 'تمام، فتحت وضع التنقل']);
    expect(feedback.startedHaptics, 1);
    expect(feedback.stoppedHaptics, 1);
    expect(controller.state, VoiceInteractionState.idle);
  });

  test(
    'runs the Stuff Finder second turn and selects the shared item',
    () async {
      final speech = _FakeVoiceCommandService(locales: ['ar-SA']);
      final feedback = _FakeVoiceFeedback();
      final controller = VoiceInteractionController(
        speech,
        feedback,
        modeTransitionDelay: Duration.zero,
      );
      final selectedItems = <StuffFinderItem>[];
      controller.bindModeSelection((_) {});
      controller.bindStuffFinderHandlers(
        onItemSelected: selectedItems.add,
        onShowAvailableItems: () {},
      );

      await controller.triggerModeListening();
      speech.emit('افتح البحث', isFinal: true);
      await _flushAsync();

      expect(controller.state, VoiceInteractionState.listening);
      expect(feedback.spoken, contains('عايز تدور على إيه؟'));

      speech.emit('دورلي على المحفظة', isFinal: true);
      await _flushAsync();

      expect(selectedItems.single.detectorLabel, 'wallet');
      expect(controller.state, VoiceInteractionState.idle);
    },
  );

  test(
    'speaks available items and shows the grid for unsupported item',
    () async {
      final speech = _FakeVoiceCommandService(locales: ['ar']);
      final feedback = _FakeVoiceFeedback();
      final controller = VoiceInteractionController(speech, feedback);
      var showedItems = false;
      controller.bindStuffFinderHandlers(
        onItemSelected: (_) {},
        onShowAvailableItems: () => showedItems = true,
      );

      await controller.beginStuffFinderItemListening();
      speech.emit('دورلي على السماعة', isFinal: true);
      await _flushAsync();

      expect(showedItems, isTrue);
      expect(
        feedback.spoken.last,
        contains('العنصر ده مش متاح حاليًا. المتاح: محفظة'),
      );
    },
  );

  test('accepts a Stuff Finder item from the regular voice trigger', () async {
    final speech = _FakeVoiceCommandService(locales: ['ar-EG']);
    final feedback = _FakeVoiceFeedback();
    final controller = VoiceInteractionController(speech, feedback);
    final selectedItems = <StuffFinderItem>[];
    controller.bindModeSelection((_) {});
    controller.bindStuffFinderHandlers(
      onItemSelected: selectedItems.add,
      onShowAvailableItems: () {},
    );

    await controller.triggerModeListening();
    speech.emit('المفاتيح', isFinal: true);
    await _flushAsync();

    expect(selectedItems.single.detectorLabel, 'keys');
    expect(feedback.spoken, isNot(contains('مسمعتش الأمر بوضوح، حاول تاني')));
    expect(controller.state, VoiceInteractionState.idle);
  });

  test('accepts a mode switch while Stuff Finder is active', () async {
    final speech = _FakeVoiceCommandService(locales: ['ar-EG']);
    final feedback = _FakeVoiceFeedback();
    final controller = VoiceInteractionController(
      speech,
      feedback,
      modeTransitionDelay: Duration.zero,
    );
    final selectedModes = <AppMode>[];
    controller.bindModeSelection(selectedModes.add);
    controller.bindStuffFinderHandlers(
      onItemSelected: (_) {},
      onShowAvailableItems: () {},
    );

    await controller.triggerModeListening();
    speech.emit('افتح وضع التنقل', isFinal: true);
    await _flushAsync();

    expect(selectedModes, [AppMode.navigation]);
    expect(controller.state, VoiceInteractionState.idle);
  });

  test('hold listening stops TTS and processes speech on release', () async {
    final speech = _FakeVoiceCommandService(locales: ['ar-EG']);
    final feedback = _FakeVoiceFeedback();
    final controller = VoiceInteractionController(speech, feedback);
    final selectedItems = <StuffFinderItem>[];
    controller.bindStuffFinderHandlers(
      onItemSelected: selectedItems.add,
      onShowAvailableItems: () {},
    );

    await controller.startHoldListening();
    expect(controller.state, VoiceInteractionState.listening);
    expect(feedback.spoken, isEmpty);
    expect(feedback.stopSpeechCalls, greaterThanOrEqualTo(1));

    speech.emit('المحفظة', isFinal: false);
    await _flushAsync();
    expect(selectedItems, isEmpty);

    await controller.endHoldListening();
    await _flushAsync();

    expect(selectedItems.single.detectorLabel, 'wallet');
    expect(controller.state, VoiceInteractionState.idle);
  });
}

Future<void> _flushAsync() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeVoiceCommandService implements VoiceCommandService {
  _FakeVoiceCommandService({required this.locales});

  final List<String> locales;
  void Function(String status)? _onStatus;
  void Function(VoiceRecognitionResult result)? _onResult;
  String? selectedLocale;

  @override
  bool isListening = false;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(VoiceRecognitionError error) onError,
  }) async {
    _onStatus = onStatus;
    return true;
  }

  @override
  Future<List<String>> localeIds() async => locales;

  @override
  Future<void> listen({
    required String? localeId,
    required void Function(VoiceRecognitionResult result) onResult,
    required void Function(double level) onSoundLevel,
    required Duration listenFor,
    required Duration pauseFor,
  }) async {
    selectedLocale = localeId;
    _onResult = onResult;
    isListening = true;
    _onStatus?.call('listening');
  }

  void emit(String text, {required bool isFinal}) {
    _onResult?.call(VoiceRecognitionResult(text: text, isFinal: isFinal));
  }

  @override
  Future<void> stop() async {
    isListening = false;
  }

  @override
  Future<void> cancel() async {
    isListening = false;
  }
}

class _FakeVoiceFeedback implements VoiceInteractionFeedback {
  final List<String> spoken = [];
  int startedHaptics = 0;
  int stoppedHaptics = 0;
  int stopSpeechCalls = 0;

  @override
  Future<void> playListeningStartedHaptic() async {
    startedHaptics++;
  }

  @override
  Future<void> playListeningStoppedHaptic() async {
    stoppedHaptics++;
  }

  @override
  Future<void> speakAndWait(String message) async {
    spoken.add(message);
  }

  @override
  Future<void> stopSpeech() async {
    stopSpeechCalls++;
  }
}
