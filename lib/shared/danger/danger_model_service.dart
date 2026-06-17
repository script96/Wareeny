import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/shared/danger/danger_alert_manager.dart';
import 'package:wareeny/shared/danger/danger_config.dart';
import 'package:wareeny/shared/danger/danger_detection_result.dart';
import 'package:wareeny/shared/danger/danger_label_mapper.dart';

typedef DangerFrameCapture = Future<Uint8List?> Function();
typedef DangerNavigationModeProvider = DangerNavigationMode Function();
typedef ExitSearchProvider = bool Function();

abstract interface class DangerInferenceEngine {
  Future<void> load();

  Future<DangerModelFrame> predict(
    Uint8List imageBytes, {
    required int frameId,
  });

  Future<void> dispose();
}

class DangerModelFrame {
  const DangerModelFrame({
    required this.frameId,
    required this.sourceSize,
    required this.detections,
    required this.timestamp,
    this.inferenceTime,
  });

  final int frameId;
  final Size sourceSize;
  final List<DangerRawDetection> detections;
  final DateTime timestamp;
  final Duration? inferenceTime;
}

class YoloDangerInferenceEngine implements DangerInferenceEngine {
  YoloDangerInferenceEngine({
    String? modelPath,
    this.maxDetections = DangerModeConfig.maxDetectionsPerFrame,
    this.diagnosticsEnabled = false,
  }) : modelPath = modelPath ?? DangerModeConfig.modelPath;

  final String modelPath;
  final int maxDetections;
  final bool diagnosticsEnabled;

  YOLO? _yolo;
  bool _loaded = false;
  String? _resolvedModelPath;

  @visibleForTesting
  String? get resolvedModelPathForTesting => _resolvedModelPath;

  @override
  Future<void> load() async {
    if (_loaded) return;
    final resolvedModelPath = await _prepareBundledModelFile(modelPath);
    _log('Danger model path asset=$modelPath resolved=$resolvedModelPath');

    final metadata = await _inspectMetadata(resolvedModelPath);
    _log('model inspect metadata=$metadata');

    final yolo = YOLO(
      modelPath: resolvedModelPath,
      task: YOLOTask.detect,
      useGpu: false,
      useMultiInstance: true,
      numItemsThreshold: maxDetections,
    );
    _yolo = yolo;
    _resolvedModelPath = resolvedModelPath;
    final loaded = await yolo.loadModel();
    if (!loaded) {
      throw StateError('Danger model failed to load: $resolvedModelPath');
    }
    _loaded = true;
    _log('danger YOLO model loaded');
  }

  Future<Map<String, dynamic>> _inspectMetadata(
    String resolvedModelPath,
  ) async {
    try {
      return await YOLO.inspectModel(resolvedModelPath);
    } catch (error) {
      _log('model metadata inspect failed: $error');
      return const <String, dynamic>{};
    }
  }

  @visibleForTesting
  Future<String> prepareBundledModelFileForTesting(String assetPath) {
    return _prepareBundledModelFile(assetPath);
  }

  Future<String> _prepareBundledModelFile(String assetPath) async {
    if (!assetPath.startsWith('assets/')) return assetPath;
    if (assetPath.endsWith('.mlpackage.zip')) {
      // Let ultralytics_yolo resolve and extract iOS Core ML archives itself.
      return assetPath;
    }

    final assetData = await rootBundle.load(assetPath);
    final bytes = assetData.buffer.asUint8List(
      assetData.offsetInBytes,
      assetData.lengthInBytes,
    );
    if (bytes.isEmpty) {
      throw StateError('Danger model asset is empty: $assetPath');
    }

    final safeName = assetPath.split('/').last;
    final directory = Directory('${Directory.systemTemp.path}/wareeny_models');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final file = File('${directory.path}/$safeName');
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      file.writeAsBytesSync(bytes, flush: true);
    }
    _log('prepared model file=${file.path} bytes=${bytes.length}');
    return file.path;
  }

  @override
  Future<DangerModelFrame> predict(
    Uint8List imageBytes, {
    required int frameId,
  }) async {
    final yolo = _yolo;
    if (!_loaded || yolo == null) {
      throw StateError('Danger model is not loaded.');
    }

    final stopwatch = Stopwatch()..start();
    final result = await yolo.predict(
      imageBytes,
      confidenceThreshold: 0.01,
      iouThreshold: 0.45,
    );
    stopwatch.stop();

    final sourceSize = _sourceSizeFromResult(result);
    final detections = _parseRawDetections(result, sourceSize)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final limited = detections.take(maxDetections).toList(growable: false);
    _log(
      'inference time=${stopwatch.elapsedMilliseconds} ms rawDetections=${limited.length}',
    );

    return DangerModelFrame(
      frameId: frameId,
      sourceSize: sourceSize,
      detections: limited,
      timestamp: DateTime.now(),
      inferenceTime: stopwatch.elapsed,
    );
  }

  Size _sourceSizeFromResult(Map<String, dynamic> result) {
    final imageSize = result['imageSize'];
    if (imageSize is Map) {
      final width = _number(imageSize['width']);
      final height = _number(imageSize['height']);
      if (width > 0 && height > 0) return Size(width, height);
    }
    return const Size(1, 1);
  }

  List<DangerRawDetection> _parseRawDetections(
    Map<String, dynamic> result,
    Size sourceSize,
  ) {
    final rawDetections = result['detections'];
    if (rawDetections is! List) return const <DangerRawDetection>[];
    final parsed = <DangerRawDetection>[];
    for (final item in rawDetections.whereType<Map>()) {
      final detection = _rawDetectionFromMap(
        Map<Object?, Object?>.from(item),
        sourceSize,
      );
      if (detection != null) parsed.add(detection);
    }
    return parsed;
  }

  DangerRawDetection? _rawDetectionFromMap(
    Map<Object?, Object?> data,
    Size sourceSize,
  ) {
    final label = data['className']?.toString().trim();
    final confidence = _number(data['confidence']).clamp(0, 1).toDouble();
    final boxData = data['boundingBox'];
    final normalizedBoxData = data['normalizedBox'];

    Rect? box;
    if (boxData is Map) {
      final raw = Map<Object?, Object?>.from(boxData);
      box = Rect.fromLTRB(
        _number(raw['left']),
        _number(raw['top']),
        _number(raw['right']),
        _number(raw['bottom']),
      );
    } else if (normalizedBoxData is Map) {
      final raw = Map<Object?, Object?>.from(normalizedBoxData);
      box = Rect.fromLTRB(
        _number(raw['left']) * sourceSize.width,
        _number(raw['top']) * sourceSize.height,
        _number(raw['right']) * sourceSize.width,
        _number(raw['bottom']) * sourceSize.height,
      );
    }
    if (box == null || box.width <= 0 || box.height <= 0) return null;

    return DangerRawDetection(
      label: label?.isNotEmpty == true ? label! : 'unknown',
      confidence: confidence,
      boundingBox: box,
      trackingId: data['trackingId']?.toString(),
    );
  }

  @override
  Future<void> dispose() async {
    await _yolo?.dispose();
    _yolo = null;
    _loaded = false;
    _resolvedModelPath = null;
    _log('danger YOLO model disposed');
  }

  void _log(String message) {
    if (diagnosticsEnabled) debugPrint('[DangerModel] $message');
  }
}

class DangerModelService extends ChangeNotifier {
  DangerModelService({
    required this.alertManager,
    DangerInferenceEngine? inferenceEngine,
    DangerLabelMapper? labelMapper,
    this.enabled = DangerModeConfig.enabled,
    this.inferenceInterval = DangerModeConfig.inferenceInterval,
    this.labelsAssetPath = DangerModeConfig.labelsPath,
    this.metadataAssetPath = DangerModeConfig.exportMetadataPath,
    this.diagnosticsEnabled = false,
  }) : _engine =
           inferenceEngine ??
           YoloDangerInferenceEngine(diagnosticsEnabled: diagnosticsEnabled),
       _labelMapper =
           labelMapper ??
           DangerLabelMapper(diagnosticsEnabled: diagnosticsEnabled) {
    alertManager.addListener(_handleAlertChanged);
  }

  final DangerAlertManager alertManager;
  final DangerInferenceEngine _engine;
  final DangerLabelMapper _labelMapper;
  final bool enabled;
  final Duration inferenceInterval;
  final String labelsAssetPath;
  final String metadataAssetPath;
  final bool diagnosticsEnabled;

  DangerFrameCapture? _captureFrame;
  DangerNavigationModeProvider? _navigationModeProvider;
  ExitSearchProvider? _exitSearchProvider;
  Timer? _timer;
  bool _started = false;
  bool _modelReady = false;
  bool _inferenceInFlight = false;
  int _nextDangerFrameId = 1;

  String status = 'Danger detector waiting for Nav mode';
  String labelsStatus = 'Danger labels not loaded';
  String alertStatus = 'No danger alerts yet';
  String tensorStatus = 'Danger tensor shape unknown';
  List<String> labels = const [];
  DangerDetectionFrame? latestFrame;
  List<DangerDetectionResult> latestDetections = const [];
  Duration? lastInferenceTime;
  int dangerModelRuns = 0;
  int dangerFramesWithDetections = 0;
  int droppedTicks = 0;

  bool get isRunning => _started;
  bool get modelReady => _modelReady;
  bool get inferenceInFlight => _inferenceInFlight;

  Future<void> start({
    required DangerFrameCapture captureFrame,
    required DangerNavigationModeProvider navigationMode,
    required ExitSearchProvider exitSearchActive,
  }) async {
    if (!enabled) {
      status = 'Danger detector disabled';
      notifyListeners();
      return;
    }
    if (_started) return;
    _started = true;
    _captureFrame = captureFrame;
    _navigationModeProvider = navigationMode;
    _exitSearchProvider = exitSearchActive;
    status = 'Danger detector starting';
    notifyListeners();

    await _loadLabels();
    await _loadExportMetadata();

    try {
      await _engine.load();
      _modelReady = true;
      status = 'Danger model loaded';
      _log('model loaded; interval=${inferenceInterval.inMilliseconds} ms');
      _timer = Timer.periodic(inferenceInterval, (_) => unawaited(runOnce()));
      unawaited(runOnce());
    } catch (error, stackTrace) {
      _modelReady = false;
      status = 'Danger model unavailable: $error';
      _log('$status\n$stackTrace');
      unawaited(alertManager.speakModelUnavailableOnce(error.toString()));
    }
    notifyListeners();
  }

  Future<void> stop({bool notify = true}) async {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    _timer = null;
    _captureFrame = null;
    _navigationModeProvider = null;
    _exitSearchProvider = null;
    _inferenceInFlight = false;
    _modelReady = false;
    await _engine.dispose();
    latestFrame = null;
    latestDetections = const [];
    status = 'Danger detector stopped';
    _log(status);
    if (notify) notifyListeners();
  }

  Future<void> runOnce() async {
    if (!_started || !_modelReady) return;
    if (_inferenceInFlight) {
      droppedTicks++;
      status = 'Dropped danger tick; inference busy';
      _log(status);
      notifyListeners();
      return;
    }
    final capture = _captureFrame;
    if (capture == null) return;

    _inferenceInFlight = true;
    notifyListeners();
    try {
      final bytes = await capture();
      if (bytes == null || bytes.isEmpty) {
        status = 'Danger frame capture unavailable';
        _log(status);
        return;
      }
      final rawFrame = await _engine.predict(
        bytes,
        frameId: _nextDangerFrameId++,
      );
      dangerModelRuns++;
      lastInferenceTime = rawFrame.inferenceTime;
      status =
          'Danger inference ${rawFrame.inferenceTime?.inMilliseconds ?? 0} ms';
      _publishFrame(_mapFrame(rawFrame));
    } catch (error, stackTrace) {
      status = 'Danger inference failed: $error';
      _log('$status\n$stackTrace');
      notifyListeners();
    } finally {
      _inferenceInFlight = false;
      notifyListeners();
    }
  }

  void setExitSearchActive(bool active) {
    if (_exitSearchProvider != null) return;
    _exitSearchProvider = () => active;
  }

  DangerDetectionFrame _mapFrame(DangerModelFrame rawFrame) {
    final mode = _navigationModeProvider?.call() ?? DangerNavigationMode.indoor;
    final exitSearch = _exitSearchProvider?.call() ?? false;
    final mapped = <DangerDetectionResult>[];
    for (final raw in rawFrame.detections) {
      final mappedLabel = _labelMapper.mappedLabelFor(
        raw.label,
        labels: labels,
      );
      final kind = _labelMapper.classify(raw.label, labels: labels);
      if (kind == null) {
        _log('label/class mismatch raw="${raw.label}" labels=$labels');
        continue;
      }

      final ignoredReason = _ignoredReasonFor(
        kind: kind,
        confidence: raw.confidence,
        navigationMode: mode,
        exitSearchActive: exitSearch,
      );
      var result = DangerDetectionResult(
        kind: kind,
        rawLabel: raw.label,
        mappedLabel: mappedLabel,
        confidence: raw.confidence,
        boundingBox: raw.boundingBox,
        sourceSize: rawFrame.sourceSize,
        navigationMode: mode,
        trackingId: raw.trackingId,
        ignoredReason: ignoredReason,
      );
      final cooldown = alertManager.cooldownStateFor(result);
      if (cooldown.blocked) {
        result = result.copyWith(
          cooldownBlocked: true,
          cooldownRemaining: cooldown.remaining,
        );
      }
      mapped.add(result);
      _log(
        'detection frame=${rawFrame.frameId} label="${raw.label}" '
        'mapped="${result.mappedLabel}" kind=${kind.name} '
        'confidence=${raw.confidence.toStringAsFixed(2)} '
        'threshold=${kind.confidenceThreshold.toStringAsFixed(2)} '
        'mode=${mode.name} ignored=${result.ignoredReason ?? "no"} '
        'cooldownBlocked=${result.cooldownBlocked} '
        'box=${raw.boundingBox}',
      );
    }

    mapped.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      return b.confidence.compareTo(a.confidence);
    });

    return DangerDetectionFrame(
      frameId: rawFrame.frameId,
      sourceSize: rawFrame.sourceSize,
      detections: mapped,
      timestamp: rawFrame.timestamp,
      modelSource: 'danger',
      inferenceTime: rawFrame.inferenceTime,
    );
  }

  String? _ignoredReasonFor({
    required DangerKind kind,
    required double confidence,
    required DangerNavigationMode navigationMode,
    required bool exitSearchActive,
  }) {
    if (confidence < kind.confidenceThreshold) {
      return 'below ${kind.confidenceThreshold.toStringAsFixed(2)} threshold';
    }
    if (kind == DangerKind.stopSign &&
        navigationMode != DangerNavigationMode.outdoor) {
      return 'stop sign ignored outside Outdoor Nav';
    }
    if (kind == DangerKind.exitSign) {
      if (navigationMode != DangerNavigationMode.indoor) {
        return 'exit sign ignored outside Indoor Nav';
      }
      if (!exitSearchActive) {
        return 'exit sign ignored; find-exit is inactive';
      }
    }
    return null;
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString(labelsAssetPath);
      labels = raw
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      final missing = _labelMapper.validateLabels(labels);
      labelsStatus = missing.isEmpty
          ? 'Loaded ${labels.length} danger labels'
          : 'Loaded ${labels.length} danger labels; missing mappings: ${missing.join(", ")}';
      _log('$labelsStatus: $labels');
    } catch (error) {
      labels = const [];
      labelsStatus = 'Danger labels unavailable: $error';
      _log(labelsStatus);
    }
  }

  Future<void> _loadExportMetadata() async {
    try {
      final raw = await rootBundle.loadString(metadataAssetPath);
      final metadata = jsonDecode(raw);
      if (metadata is Map) {
        final source = metadata['source_weights'];
        final runtime = metadata['runtime'];
        final optimized = metadata['optimized'];
        final model = runtime is Map ? runtime : optimized;
        final inputs = model is Map ? model['inputs'] : null;
        final outputs = model is Map ? model['outputs'] : null;
        tensorStatus = 'Input tensor: $inputs | Output tensor: $outputs';
        _log('model conversion/export source=$source runtime=$model');
        _log(tensorStatus);
      }
    } catch (error) {
      tensorStatus = 'Danger export metadata unavailable: $error';
      _log(tensorStatus);
    }
  }

  void _publishFrame(DangerDetectionFrame frame) {
    latestFrame = frame;
    latestDetections = frame.detections;
    if (frame.detections.isNotEmpty) {
      dangerFramesWithDetections++;
    }
    unawaited(alertManager.handleFrame(frame.detections));
    notifyListeners();
  }

  void _handleAlertChanged() {
    alertStatus = alertManager.status;
    notifyListeners();
  }

  void _log(String message) {
    if (diagnosticsEnabled) debugPrint('[DangerModel] $message');
  }

  @override
  void dispose() {
    _timer?.cancel();
    alertManager.removeListener(_handleAlertChanged);
    unawaited(_engine.dispose());
    super.dispose();
  }
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
