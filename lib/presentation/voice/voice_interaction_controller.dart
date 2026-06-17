import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_items.dart';
import 'package:wareeny/presentation/voice/arabic_command_parser.dart';
import 'package:wareeny/presentation/voice/voice_command_service.dart';
import 'package:wareeny/presentation/voice/voice_interaction_feedback.dart';

export 'package:wareeny/presentation/voice/voice_interaction_feedback.dart';

enum VoiceInteractionState {
  idle,
  prompting,
  listening,
  hearingSpeech,
  processing,
  error,
}

enum _ListeningPurpose { mode, stuffFinder }

typedef VoiceModeSelection = FutureOr<void> Function(AppMode mode);
typedef VoiceStuffFinderSelection =
    FutureOr<void> Function(StuffFinderItem item);
typedef ShowStuffFinderItems = FutureOr<void> Function();

class VoiceInteractionController extends ChangeNotifier {
  VoiceInteractionController(
    this._commandService,
    this._feedback, {
    ArabicCommandParser? parser,
    this.commandCooldown = const Duration(seconds: 2),
    this.modeTransitionDelay = const Duration(milliseconds: 150),
  }) : _parser = parser ?? const ArabicCommandParser();

  final VoiceCommandService _commandService;
  final VoiceInteractionFeedback _feedback;
  final ArabicCommandParser _parser;
  final Duration commandCooldown;
  final Duration modeTransitionDelay;

  static const _listenFor = Duration(seconds: 8);
  static const _pauseFor = Duration(milliseconds: 2200);
  static const _holdListenFor = Duration(seconds: 30);
  static const _holdPauseFor = Duration(seconds: 30);

  VoiceModeSelection? _onModeSelected;
  VoiceStuffFinderSelection? _onStuffFinderItemSelected;
  ShowStuffFinderItems? _onShowStuffFinderItems;
  _ListeningPurpose _purpose = _ListeningPurpose.mode;
  VoiceInteractionState _state = VoiceInteractionState.idle;
  DateTime? _cooldownUntil;
  String? _preferredLocaleId;
  String _latestText = '';
  bool _initialized = false;
  bool _resultHandled = false;
  bool _endingSession = false;
  bool _holdActive = false;
  double _minimumSoundLevel = double.infinity;
  double _maximumSoundLevel = double.negativeInfinity;
  double _soundLevel = 0;

  VoiceInteractionState get state => _state;
  double get soundLevel => _soundLevel;
  bool get isActive => _state != VoiceInteractionState.idle;
  bool get isHearingSpeech => _state == VoiceInteractionState.hearingSpeech;
  bool get isListening =>
      _state == VoiceInteractionState.listening ||
      _state == VoiceInteractionState.hearingSpeech;
  bool get isCapturingSpeech =>
      _state == VoiceInteractionState.prompting || isListening;

  String get semanticLabel => switch (_state) {
    VoiceInteractionState.idle => 'اضغط مطولًا على الشاشة لإعطاء أمر صوتي',
    VoiceInteractionState.prompting => 'التطبيق يستعد للاستماع',
    VoiceInteractionState.listening => 'التطبيق يستمع الآن',
    VoiceInteractionState.hearingSpeech => 'التطبيق يسمع كلامك الآن',
    VoiceInteractionState.processing => 'جاري تنفيذ الأمر الصوتي',
    VoiceInteractionState.error => 'حدث خطأ في الاستماع',
  };

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
    await _beginListening(purpose: _currentPurpose, prompt: 'اتكلم');
  }

  Future<void> startHoldListening() async {
    if (_cooldownIsActive) return;
    if (isActive) {
      await cancel();
    }
    _holdActive = true;
    await _beginListening(
      purpose: _currentPurpose,
      listenFor: _holdListenFor,
      pauseFor: _holdPauseFor,
      requiresActiveHold: true,
    );
  }

  Future<void> endHoldListening() async {
    if (!_holdActive) return;
    _holdActive = false;
    if (isListening) {
      await _handleRecognizedText(_latestText);
    } else if (_state == VoiceInteractionState.prompting) {
      await cancel();
    }
  }

  Future<void> cancelHoldListening() async {
    if (!_holdActive) return;
    _holdActive = false;
    await cancel();
  }

  Future<void> beginStuffFinderItemListening() async {
    if (isActive) {
      await cancel();
    }
    await _beginListening(
      purpose: _ListeningPurpose.stuffFinder,
      prompt: 'عايز تدور على إيه؟',
    );
  }

  Future<void> cancel() async {
    _holdActive = false;
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

  Future<void> interruptForDangerAlert() async {
    _holdActive = false;
    _resultHandled = true;
    _endingSession = true;
    try {
      await _commandService.cancel();
    } catch (error) {
      debugPrint('[VoiceInteraction] Danger interrupt failed: $error');
    }
    await _feedback.stopSpeech();
    _setState(VoiceInteractionState.idle);
    _endingSession = false;
  }

  Future<void> _beginListening({
    required _ListeningPurpose purpose,
    String? prompt,
    Duration listenFor = _listenFor,
    Duration pauseFor = _pauseFor,
    bool requiresActiveHold = false,
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
    if (prompt != null) {
      await _feedback.speakAndWait(prompt);
    }

    if (!await _ensureInitialized()) return;
    if (requiresActiveHold && !_holdActive) {
      _setState(VoiceInteractionState.idle);
      return;
    }

    try {
      await _feedback.stopSpeech();
      await _feedback.playListeningStartedHaptic();
      _setState(VoiceInteractionState.listening);
      final listenMode = purpose == _ListeningPurpose.stuffFinder
          ? ListenMode.search
          : ListenMode.confirmation;
      await _commandService.listen(
        localeId: _preferredLocaleId,
        onResult: _onSpeechResult,
        onSoundLevel: _onSoundLevel,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenMode: listenMode,
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
    if (result.isFinal && !_holdActive) {
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
    if (!_holdActive && (status == 'done' || status == 'notListening')) {
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

    if (rawText.trim().isEmpty) {
      await _speakError('مسمعتش الكلام بوضوح، حاول تاني');
      return;
    }

    if (_purpose == _ListeningPurpose.stuffFinder) {
      await _handleStuffFinderCommand(rawText);
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
      await _speakError('مسمعتش الكلام بوضوح، حاول تاني');
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

  Future<void> _handleStuffFinderCommand(String rawText) async {
    final parsed = _parser.parseStuffFinderItem(rawText);
    if (parsed == null) {
      final mode = _parser.parseMode(rawText);
      if (mode != null && _onModeSelected != null) {
        await _handleMode(rawText);
        return;
      }
    }

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
        'الحاجة دي مش متاحة دلوقتي. المتاح: '
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
          ? 'لازم تسمح لوريني يستخدم الميكروفون ويتعرف على الكلام'
          : 'مسمعتش الكلام بوضوح، حاول تاني',
    );
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

  _ListeningPurpose get _currentPurpose => _onStuffFinderItemSelected == null
      ? _ListeningPurpose.mode
      : _ListeningPurpose.stuffFinder;

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
    AppMode.inHand => 'في اليد',
    AppMode.read => 'القراءة',
    AppMode.settings => 'الإعدادات',
  };

  @override
  void dispose() {
    unawaited(_commandService.cancel());
    super.dispose();
  }
}
