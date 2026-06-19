import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_items.dart';
import 'package:wareeny/presentation/voice/arabic_command_parser.dart';
import 'package:wareeny/presentation/voice/voice_command_service.dart';
import 'package:wareeny/presentation/voice/voice_interaction_feedback.dart';
import 'package:wareeny/presentation/voice/volume_button_trigger_service.dart';

export 'package:wareeny/presentation/voice/voice_interaction_feedback.dart';

enum VoiceInteractionState {
  idle,
  prompting,
  listening,
  hearingSpeech,
  processing,
  error,
}

enum _ListeningPurpose { mode, stuffFinderItem, freeformQuestion }

typedef VoiceModeSelection = FutureOr<void> Function(AppMode mode);
typedef VoiceStuffFinderSelection =
    FutureOr<void> Function(StuffFinderItem item);
typedef ShowStuffFinderItems = FutureOr<void> Function();

class VoiceInteractionController extends ChangeNotifier {
  VoiceInteractionController(
    this._commandService,
    this._feedback, {
    VolumeButtonTriggerService? volumeTrigger,
    ArabicCommandParser? parser,
    this.commandCooldown = const Duration(seconds: 2),
    this.modeTransitionDelay = const Duration(milliseconds: 150),
  }) : _volumeTrigger = volumeTrigger ?? const VolumeButtonTriggerService(),
       _parser = parser ?? const ArabicCommandParser();

  final VoiceCommandService _commandService;
  final VoiceInteractionFeedback _feedback;
  final VolumeButtonTriggerService _volumeTrigger;
  final ArabicCommandParser _parser;
  final Duration commandCooldown;
  final Duration modeTransitionDelay;

  static const _listenFor = Duration(seconds: 8);
  static const _pauseFor = Duration(milliseconds: 2200);

  StreamSubscription<void>? _volumeSubscription;
  VoiceModeSelection? _onModeSelected;
  VoiceStuffFinderSelection? _onStuffFinderItemSelected;
  ShowStuffFinderItems? _onShowStuffFinderItems;
  _ListeningPurpose _purpose = _ListeningPurpose.mode;
  Completer<String?>? _questionCompleter;
  VoiceInteractionState _state = VoiceInteractionState.idle;
  DateTime? _cooldownUntil;
  String? _preferredLocaleId;
  String _latestText = '';
  bool _initialized = false;
  bool _resultHandled = false;
  bool _endingSession = false;
  double _minimumSoundLevel = double.infinity;
  double _maximumSoundLevel = double.negativeInfinity;
  double _soundLevel = 0;

  VoiceInteractionState get state => _state;
  double get soundLevel => _soundLevel;
  bool get isActive => _state != VoiceInteractionState.idle;
  bool get isHearingSpeech => _state == VoiceInteractionState.hearingSpeech;

  String get semanticLabel => switch (_state) {
    VoiceInteractionState.idle => 'اضغط مرتين أو ضغطة مطولة لإعطاء أمر صوتي',
    VoiceInteractionState.prompting => 'التطبيق يستعد للاستماع',
    VoiceInteractionState.listening => 'التطبيق يستمع الآن',
    VoiceInteractionState.hearingSpeech => 'التطبيق يسمع كلامك الآن',
    VoiceInteractionState.processing => 'جاري تنفيذ الأمر الصوتي',
    VoiceInteractionState.error => 'حدث خطأ في الاستماع',
  };

  void startHardwareTrigger() {
    _volumeSubscription ??= _volumeTrigger.triggers.listen((_) {
      unawaited(triggerModeListening());
    });
  }

  void bindModeSelection(VoiceModeSelection handler) {
    _onModeSelected = handler;
  }

  void clearModeSelection() {
    _onModeSelected = null;
  }

  void bindStuffFinderHandlers({
    required VoiceStuffFinderSelection onItemSelected,
    required ShowStuffFinderItems onShowAvailableItems,
  }) {
    _onStuffFinderItemSelected = onItemSelected;
    _onShowStuffFinderItems = onShowAvailableItems;
  }

  void clearStuffFinderHandlers() {
    _onStuffFinderItemSelected = null;
    _onShowStuffFinderItems = null;
  }

  Future<void> triggerModeListening() async {
    if (isActive || _cooldownIsActive) return;
    await _beginListening(purpose: _ListeningPurpose.mode, prompt: 'اتكلم');
  }

  Future<void> beginStuffFinderItemListening() async {
    if (isActive) {
      await cancel();
    }
    await _beginListening(
      purpose: _ListeningPurpose.stuffFinderItem,
      prompt: 'عايز تدور على إيه؟',
    );
  }

  /// Listens for a free-form spoken utterance and returns the raw recognized
  /// text — used by the QA feature to capture a question, bypassing the command
  /// parser. Returns null if nothing was heard, the mic was denied, or STT
  /// failed (the controller speaks its own feedback in those cases). Cancels any
  /// in-flight listening session first.
  Future<String?> listenForQuestion(String prompt) async {
    if (isActive) {
      await cancel();
    }
    final completer = Completer<String?>();
    _questionCompleter = completer;
    await _beginListening(
      purpose: _ListeningPurpose.freeformQuestion,
      prompt: prompt,
    );
    return completer.future;
  }

  void _completeQuestion(String? value) {
    final completer = _questionCompleter;
    _questionCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  Future<void> cancel() async {
    _completeQuestion(null);
    _endingSession = true;
    try {
      await _commandService.cancel();
    } catch (error) {
      debugPrint('[VoiceInteraction] Cancel failed: $error');
    }
    await _finishListeningHaptic();
    _setState(VoiceInteractionState.idle);
    _endingSession = false;
  }

  Future<void> _beginListening({
    required _ListeningPurpose purpose,
    required String prompt,
  }) async {
    _purpose = purpose;
    _latestText = '';
    _resultHandled = false;
    _endingSession = false;
    _minimumSoundLevel = double.infinity;
    _maximumSoundLevel = double.negativeInfinity;
    _soundLevel = 0;
    _setState(VoiceInteractionState.prompting);

    await _feedback.stopSpeech();
    await _feedback.speakAndWait(prompt);

    if (!await _ensureInitialized()) return;

    try {
      await _feedback.playListeningStartedHaptic();
      _setState(VoiceInteractionState.listening);
      await _commandService.listen(
        localeId: _preferredLocaleId,
        onResult: _onSpeechResult,
        onSoundLevel: _onSoundLevel,
        listenFor: _listenFor,
        pauseFor: _pauseFor,
      );
    } catch (error, stackTrace) {
      debugPrint('[VoiceInteraction] Listen failed: $error\n$stackTrace');
      await _handleFailure('listen_failed');
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      final available = await _commandService.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (!available) {
        await _handleFailure('permission_denied');
        return false;
      }

      final localeIds = await _commandService.localeIds();
      _preferredLocaleId = _chooseArabicLocale(localeIds);
      _initialized = true;
      debugPrint(
        '[VoiceInteraction] STT initialized locale=$_preferredLocaleId '
        'available=$localeIds',
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[VoiceInteraction] STT initialization failed: $error\n$stackTrace',
      );
      await _handleFailure('initialization_failed');
      return false;
    }
  }

  void _onSpeechResult(VoiceRecognitionResult result) {
    if (_resultHandled) return;
    _latestText = result.text.trim();
    if (_latestText.isNotEmpty &&
        (_state == VoiceInteractionState.listening ||
            _state == VoiceInteractionState.hearingSpeech)) {
      _setState(VoiceInteractionState.hearingSpeech);
    }
    if (result.isFinal) {
      unawaited(_handleRecognizedText(_latestText));
    }
  }

  void _onSoundLevel(double level) {
    if (!level.isFinite) return;
    _minimumSoundLevel = level < _minimumSoundLevel
        ? level
        : _minimumSoundLevel;
    _maximumSoundLevel = level > _maximumSoundLevel
        ? level
        : _maximumSoundLevel;
    final range = _maximumSoundLevel - _minimumSoundLevel;
    _soundLevel = range < 0.5
        ? 0
        : ((level - _minimumSoundLevel) / range).clamp(0.0, 1.0);
    if (_soundLevel > 0.2 && _state == VoiceInteractionState.listening) {
      _setState(VoiceInteractionState.hearingSpeech);
    } else {
      notifyListeners();
    }
  }

  void _onSpeechStatus(String status) {
    debugPrint('[VoiceInteraction] STT status=$status');
    if (_endingSession || _resultHandled) return;
    if (status == 'done' || status == 'notListening') {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!_resultHandled && !_endingSession) {
          unawaited(_handleRecognizedText(_latestText));
        }
      });
    }
  }

  void _onSpeechError(VoiceRecognitionError error) {
    debugPrint(
      '[VoiceInteraction] STT error=${error.code} '
      'permanent=${error.isPermanent}',
    );
    if (_endingSession || _resultHandled) return;
    unawaited(_handleFailure(error.code));
  }

  Future<void> _handleRecognizedText(String rawText) async {
    if (_resultHandled) return;
    _resultHandled = true;
    await _stopForProcessing();

    final normalized = ArabicCommandParser.normalizeArabic(rawText);
    debugPrint('[VoiceInteraction] recognized raw="$rawText"');
    debugPrint('[VoiceInteraction] normalized="$normalized"');

    if (_purpose == _ListeningPurpose.freeformQuestion) {
      final question = rawText.trim();
      if (question.isEmpty) {
        await _speakError('مسمعتش سؤالك، حاول تاني');
        _completeQuestion(null);
      } else {
        _setState(VoiceInteractionState.idle);
        _completeQuestion(question);
      }
      return;
    }

    if (rawText.trim().isEmpty) {
      await _speakError('مسمعتش الأمر بوضوح، حاول تاني');
      return;
    }

    if (_purpose == _ListeningPurpose.stuffFinderItem) {
      await _handleStuffFinderItem(rawText);
      return;
    }
    await _handleMode(rawText);
  }

  Future<void> _handleMode(String rawText) async {
    final parsed = _parser.parseMode(rawText);
    debugPrint(
      '[VoiceInteraction] detected intent='
      '${parsed == null ? "unknown" : "mode.${parsed.mode.name}"}',
    );
    if (parsed == null || _onModeSelected == null) {
      await _speakError('مسمعتش الأمر بوضوح، حاول تاني');
      return;
    }

    _cooldownUntil = DateTime.now().add(commandCooldown);
    await _onModeSelected!(parsed.mode);
    await Future<void>.delayed(modeTransitionDelay);
    await _feedback.speakAndWait(
      'تمام، فتحت وضع ${_arabicModeName(parsed.mode)}',
    );

    if (parsed.mode == AppMode.stuffFinder) {
      await beginStuffFinderItemListening();
      return;
    }
    _setState(VoiceInteractionState.idle);
  }

  Future<void> _handleStuffFinderItem(String rawText) async {
    final parsed = _parser.parseStuffFinderItem(rawText);
    debugPrint(
      '[VoiceInteraction] detected intent='
      '${parsed == null ? "unsupported_item" : "stuff_finder_item"}',
    );
    debugPrint(
      '[VoiceInteraction] selected item='
      '${parsed?.item.detectorLabel ?? "none"}',
    );

    final selectionHandler = _onStuffFinderItemSelected;
    if (parsed == null || selectionHandler == null) {
      await _feedback.speakAndWait(
        'العنصر ده مش متاح حاليًا. المتاح: '
        '$availableStuffFinderItemsArabic',
      );
      _setState(VoiceInteractionState.idle);
      await _onShowStuffFinderItems?.call();
      return;
    }

    await selectionHandler(parsed.item);
    _cooldownUntil = DateTime.now().add(commandCooldown);
    _setState(VoiceInteractionState.idle);
  }

  Future<void> _stopForProcessing() async {
    _endingSession = true;
    try {
      if (_commandService.isListening) {
        await _commandService.stop();
      }
    } catch (error) {
      debugPrint('[VoiceInteraction] Stop failed: $error');
    }
    await _finishListeningHaptic();
    _setState(VoiceInteractionState.processing);
    _endingSession = false;
  }

  Future<void> _handleFailure(String code) async {
    if (_resultHandled) return;
    _resultHandled = true;
    _endingSession = true;
    try {
      await _commandService.cancel();
    } catch (_) {}
    await _finishListeningHaptic();
    debugPrint('[VoiceInteraction] STT failure code=$code');
    final denied = code.contains('permission') || code.contains('notAllowed');
    await _speakError(
      denied
          ? 'لازم تسمح لوريني باستخدام الميكروفون والتعرف على الكلام'
          : 'مسمعتش الأمر بوضوح، حاول تاني',
    );
    _completeQuestion(null);
    _endingSession = false;
  }

  Future<void> _speakError(String message) async {
    _setState(VoiceInteractionState.error);
    await _feedback.speakAndWait(message);
    _setState(VoiceInteractionState.idle);
  }

  Future<void> _finishListeningHaptic() async {
    if (_state == VoiceInteractionState.listening ||
        _state == VoiceInteractionState.hearingSpeech) {
      await _feedback.playListeningStoppedHaptic();
    }
  }

  bool get _cooldownIsActive {
    final until = _cooldownUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _setState(VoiceInteractionState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  static String? _chooseArabicLocale(List<String> localeIds) {
    String normalized(String value) => value.toLowerCase().replaceAll('_', '-');

    for (final locale in localeIds) {
      if (normalized(locale) == 'ar-eg') return locale;
    }
    for (final locale in localeIds) {
      if (normalized(locale).startsWith('ar')) return locale;
    }
    return null;
  }

  static String _arabicModeName(AppMode mode) => switch (mode) {
    AppMode.home => 'الرئيسية',
    AppMode.navigation => 'التنقل',
    AppMode.stuffFinder => 'البحث عن الأشياء',
    AppMode.scan => 'المسح',
    AppMode.read => 'القراءة',
    AppMode.settings => 'الإعدادات',
  };

  @override
  void dispose() {
    _completeQuestion(null);
    _volumeSubscription?.cancel();
    unawaited(_commandService.cancel());
    super.dispose();
  }
}
