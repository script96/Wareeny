import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

enum LightCondition { normal, lowLight, veryDark }

class LightConditionConfig {
  const LightConditionConfig({
    this.veryDarkAverage = 35,
    this.lowLightAverage = 55,
    this.darkPixelThreshold = 45,
    this.darkRatio = 0.65,
    this.veryDarkRatio = 0.85,
    this.veryDarkDelay = const Duration(seconds: 5),
    this.lowLightDelay = const Duration(seconds: 10),
    this.maximumDarkDelay = const Duration(seconds: 15),
    this.recoveryDelay = const Duration(seconds: 3),
    this.warningCooldown = const Duration(seconds: 30),
    this.smoothingWindow = 6,
    this.sampleStride = 8,
    this.pathWeight = 2,
  });

  final double veryDarkAverage;
  final double lowLightAverage;
  final int darkPixelThreshold;
  final double darkRatio;
  final double veryDarkRatio;
  final Duration veryDarkDelay;
  final Duration lowLightDelay;
  final Duration maximumDarkDelay;
  final Duration recoveryDelay;
  final Duration warningCooldown;
  final int smoothingWindow;
  final int sampleStride;

  /// Extra weight for pixels in the lower-center navigation path.
  final int pathWeight;
}

class LightFrameStats {
  const LightFrameStats({
    required this.averageBrightness,
    required this.darkPixelRatio,
    required this.sampleCount,
  });

  final double averageBrightness;
  final double darkPixelRatio;
  final int sampleCount;
}

class LightConditionResult {
  const LightConditionResult({
    required this.averageBrightness,
    required this.darkPixelRatio,
    required this.condition,
    required this.darkDuration,
    required this.flashRequested,
    required this.shouldSpeak,
    required this.recovered,
  });

  final double averageBrightness;
  final double darkPixelRatio;
  final LightCondition condition;
  final Duration darkDuration;
  final bool flashRequested;
  final bool shouldSpeak;
  final bool recovered;
}

class LightConditionService {
  LightConditionService({
    this.config = const LightConditionConfig(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LightConditionConfig config;
  final DateTime Function() _clock;
  final List<LightFrameStats> _recent = [];

  DateTime? _darkSince;
  DateTime? _veryDarkSince;
  DateTime? _normalSince;
  DateTime? _lastWarningAt;
  bool _flashRequestedForEpisode = false;

  LightFrameStats? analyzeCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final firstPlane = image.planes.first;

    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
      case ImageFormatGroup.nv21:
        return analyzeYPlane(
          bytes: firstPlane.bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: firstPlane.bytesPerRow,
        );
      case ImageFormatGroup.bgra8888:
        return analyzeBgra8888(
          bytes: firstPlane.bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: firstPlane.bytesPerRow,
          bytesPerPixel: firstPlane.bytesPerPixel ?? 4,
        );
      case ImageFormatGroup.jpeg:
        final values = analyzeEncodedLightFrame({
          'bytes': firstPlane.bytes,
          'darkPixelThreshold': config.darkPixelThreshold,
          'sampleStride': config.sampleStride,
          'pathWeight': config.pathWeight,
        });
        if (values == null) return null;
        return LightFrameStats(
          averageBrightness: values['averageBrightness']!.toDouble(),
          darkPixelRatio: values['darkPixelRatio']!.toDouble(),
          sampleCount: values['sampleCount']!.toInt(),
        );
      case ImageFormatGroup.unknown:
        if ((firstPlane.bytesPerPixel ?? 1) >= 4) {
          return analyzeBgra8888(
            bytes: firstPlane.bytes,
            width: image.width,
            height: image.height,
            bytesPerRow: firstPlane.bytesPerRow,
            bytesPerPixel: firstPlane.bytesPerPixel ?? 4,
          );
        }
        return analyzeYPlane(
          bytes: firstPlane.bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: firstPlane.bytesPerRow,
        );
    }
  }

  LightFrameStats analyzeYPlane({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    return _analyzePixels(
      width: width,
      height: height,
      brightnessAt: (x, y) {
        final index = y * bytesPerRow + x;
        return index < bytes.length ? bytes[index] : 0;
      },
    );
  }

  LightFrameStats analyzeBgra8888({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    int bytesPerPixel = 4,
  }) {
    return _analyzePixels(
      width: width,
      height: height,
      brightnessAt: (x, y) {
        final index = y * bytesPerRow + x * bytesPerPixel;
        if (index + 2 >= bytes.length) return 0;
        final blue = bytes[index];
        final green = bytes[index + 1];
        final red = bytes[index + 2];
        return (0.2126 * red + 0.7152 * green + 0.0722 * blue).round();
      },
    );
  }

  LightConditionResult addSample(LightFrameStats stats, {DateTime? timestamp}) {
    final now = timestamp ?? _clock();
    _recent.add(stats);
    if (_recent.length > config.smoothingWindow) {
      _recent.removeAt(0);
    }

    final average =
        _recent.fold<double>(
          0,
          (total, item) => total + item.averageBrightness,
        ) /
        _recent.length;
    final darkRatio =
        _recent.fold<double>(0, (total, item) => total + item.darkPixelRatio) /
        _recent.length;
    final condition = _classify(average, darkRatio);
    var recovered = false;

    if (condition == LightCondition.normal) {
      _normalSince ??= now;
      _veryDarkSince = null;
      if (_darkSince != null &&
          now.difference(_normalSince!) >= config.recoveryDelay) {
        _darkSince = null;
        _flashRequestedForEpisode = false;
        recovered = true;
      }
    } else {
      _darkSince ??= now;
      _normalSince = null;
      if (condition == LightCondition.veryDark) {
        _veryDarkSince ??= now;
      } else {
        _veryDarkSince = null;
      }
    }

    final darkDuration = _darkSince == null
        ? Duration.zero
        : now.difference(_darkSince!);
    final veryDarkDuration = _veryDarkSince == null
        ? Duration.zero
        : now.difference(_veryDarkSince!);
    final requiredSamples = config.smoothingWindow.clamp(1, 3);
    final enoughSamples = _recent.length >= requiredSamples;
    final shouldRequest =
        enoughSamples &&
        condition != LightCondition.normal &&
        !_flashRequestedForEpisode &&
        (veryDarkDuration >= config.veryDarkDelay ||
            darkDuration >= config.lowLightDelay ||
            darkDuration >= config.maximumDarkDelay);

    var shouldSpeak = false;
    if (shouldRequest) {
      _flashRequestedForEpisode = true;
      shouldSpeak =
          _lastWarningAt == null ||
          now.difference(_lastWarningAt!) >= config.warningCooldown;
      if (shouldSpeak) _lastWarningAt = now;
    }

    return LightConditionResult(
      averageBrightness: average,
      darkPixelRatio: darkRatio,
      condition: condition,
      darkDuration: darkDuration,
      flashRequested: shouldRequest,
      shouldSpeak: shouldSpeak,
      recovered: recovered,
    );
  }

  void reset({bool clearCooldown = false}) {
    _recent.clear();
    _darkSince = null;
    _veryDarkSince = null;
    _normalSince = null;
    _flashRequestedForEpisode = false;
    if (clearCooldown) _lastWarningAt = null;
  }

  LightCondition _classify(double average, double darkRatio) {
    if (average < config.veryDarkAverage && darkRatio >= config.veryDarkRatio) {
      return LightCondition.veryDark;
    }
    if (average < config.lowLightAverage && darkRatio >= config.darkRatio) {
      return LightCondition.lowLight;
    }
    return LightCondition.normal;
  }

  LightFrameStats _analyzePixels({
    required int width,
    required int height,
    required int Function(int x, int y) brightnessAt,
  }) {
    if (width <= 0 || height <= 0) {
      return const LightFrameStats(
        averageBrightness: 0,
        darkPixelRatio: 1,
        sampleCount: 0,
      );
    }

    var brightnessTotal = 0;
    var darkPixels = 0;
    var weightedSamples = 0;
    final stride = config.sampleStride.clamp(1, width);

    for (var y = 0; y < height; y += stride) {
      for (var x = 0; x < width; x += stride) {
        final brightness = brightnessAt(x, y).clamp(0, 255);
        final weight = _isInNavigationPath(x, y, width, height)
            ? config.pathWeight
            : 1;
        brightnessTotal += brightness * weight;
        if (brightness < config.darkPixelThreshold) {
          darkPixels += weight;
        }
        weightedSamples += weight;
      }
    }

    return LightFrameStats(
      averageBrightness: weightedSamples == 0
          ? 0
          : brightnessTotal / weightedSamples,
      darkPixelRatio: weightedSamples == 0 ? 1 : darkPixels / weightedSamples,
      sampleCount: weightedSamples,
    );
  }
}

Map<String, num>? analyzeEncodedLightFrame(Map<String, Object> input) {
  final bytes = input['bytes'];
  if (bytes is! Uint8List) return null;
  final image = img.decodeImage(bytes);
  if (image == null) return null;

  final darkPixelThreshold = input['darkPixelThreshold'] as int? ?? 45;
  final sampleStride = input['sampleStride'] as int? ?? 8;
  final pathWeight = input['pathWeight'] as int? ?? 2;
  var brightnessTotal = 0.0;
  var darkPixels = 0;
  var weightedSamples = 0;
  final stride = sampleStride.clamp(1, image.width);

  for (var y = 0; y < image.height; y += stride) {
    for (var x = 0; x < image.width; x += stride) {
      final pixel = image.getPixel(x, y);
      final brightness = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
      final weight = _isInNavigationPath(x, y, image.width, image.height)
          ? pathWeight
          : 1;
      brightnessTotal += brightness * weight;
      if (brightness < darkPixelThreshold) darkPixels += weight;
      weightedSamples += weight;
    }
  }

  if (weightedSamples == 0) return null;
  return {
    'averageBrightness': brightnessTotal / weightedSamples,
    'darkPixelRatio': darkPixels / weightedSamples,
    'sampleCount': weightedSamples,
  };
}

bool _isInNavigationPath(int x, int y, int width, int height) {
  final normalizedY = y / height;
  if (normalizedY < 0.48) return false;
  final progress = ((normalizedY - 0.48) / 0.52).clamp(0.0, 1.0);
  final left = 0.46 + (0.30 - 0.46) * progress;
  final right = 0.54 + (0.70 - 0.54) * progress;
  final normalizedX = x / width;
  return normalizedX >= left && normalizedX <= right;
}
