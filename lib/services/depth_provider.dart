import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

enum DepthSource { arcore, arkit, monocular }

class DepthFrame {
  final int width;
  final int height;
  final Float32List values;
  final DepthSource source;

  const DepthFrame({
    required this.width,
    required this.height,
    required this.values,
    required this.source,
  });

  double valueAt(int x, int y) {
    final safeX = x.clamp(0, width - 1);
    final safeY = y.clamp(0, height - 1);
    return values[(safeY * width) + safeX];
  }

  double sampleNormalized(double x, double y) {
    final ix = (x.clamp(0.0, 1.0) * (width - 1)).round();
    final iy = (y.clamp(0.0, 1.0) * (height - 1)).round();
    return valueAt(ix, iy);
  }
}

abstract class DepthProvider {
  String get debugName;

  Future<bool> initialize();

  Future<DepthFrame?> estimate(Uint8List imageBytes);

  Future<void> dispose() async {}
}

class ArcoreDepthProvider implements DepthProvider {
  static const MethodChannel _channel = MethodChannel('warene/depth/arcore');

  bool _supported = false;

  @override
  String get debugName => 'ARCore Depth';

  @override
  Future<bool> initialize() async {
    try {
      _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      _supported = false;
    } catch (_) {
      _supported = false;
    }
    return _supported;
  }

  @override
  Future<DepthFrame?> estimate(Uint8List imageBytes) async {
    if (!_supported) return null;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'estimateDepth',
        <String, dynamic>{'imageBytes': imageBytes},
      );
      return _depthFrameFromMap(map, DepthSource.arcore);
    } on MissingPluginException {
      _supported = false;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}

class ArkitDepthProvider implements DepthProvider {
  static const MethodChannel _channel = MethodChannel('warene/depth/arkit');

  bool _supported = false;

  @override
  String get debugName => 'ARKit Scene Depth';

  @override
  Future<bool> initialize() async {
    try {
      _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      _supported = false;
    } catch (_) {
      _supported = false;
    }
    return _supported;
  }

  @override
  Future<DepthFrame?> estimate(Uint8List imageBytes) async {
    if (!_supported) return null;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'estimateDepth',
        <String, dynamic>{'imageBytes': imageBytes},
      );
      return _depthFrameFromMap(map, DepthSource.arkit);
    } on MissingPluginException {
      _supported = false;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}

class MonocularDepthProvider implements DepthProvider {
  static const int _depthWidth = 24;
  static const int _depthHeight = 32;

  @override
  String get debugName => 'Monocular Heuristic Depth';

  @override
  Future<bool> initialize() async => true;

  @override
  Future<DepthFrame?> estimate(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final oriented = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      oriented,
      width: _depthWidth,
      height: _depthHeight,
      interpolation: img.Interpolation.average,
    );

    final values = Float32List(_depthWidth * _depthHeight);

    for (int y = 0; y < _depthHeight; y++) {
      for (int x = 0; x < _depthWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final luma =
            ((pixel.r * 0.299) + (pixel.g * 0.587) + (pixel.b * 0.114)) / 255.0;
        final right = resized.getPixel(math.min(x + 1, _depthWidth - 1), y);
        final down = resized.getPixel(x, math.min(y + 1, _depthHeight - 1));
        final contrastX =
            ((pixel.r - right.r).abs() +
                (pixel.g - right.g).abs() +
                (pixel.b - right.b).abs()) /
            (255.0 * 3.0);
        final contrastY =
            ((pixel.r - down.r).abs() +
                (pixel.g - down.g).abs() +
                (pixel.b - down.b).abs()) /
            (255.0 * 3.0);
        final edge = ((contrastX + contrastY) / 2).clamp(0.0, 1.0);

        final yNorm = y / (_depthHeight - 1);
        final xNorm = x / (_depthWidth - 1);
        final centerBias = 1.0 - ((xNorm - 0.5).abs() * 1.4).clamp(0.0, 1.0);
        final bottomBias = math.pow(yNorm, 1.25).toDouble();
        final darkness = 1.0 - luma;

        final closeness =
            ((bottomBias * 0.52) +
                    (edge * 0.28) +
                    (darkness * 0.12) +
                    (centerBias * 0.08))
                .clamp(0.0, 1.0);
        values[(y * _depthWidth) + x] = closeness;
      }
    }

    return DepthFrame(
      width: _depthWidth,
      height: _depthHeight,
      values: values,
      source: DepthSource.monocular,
    );
  }

  @override
  Future<void> dispose() async {}
}

DepthFrame? _depthFrameFromMap(Map<String, dynamic>? map, DepthSource source) {
  if (map == null) return null;
  final width = map['width'];
  final height = map['height'];
  final rawValues = map['values'];

  if (width is! int || height is! int || rawValues is! List) {
    return null;
  }

  final values = Float32List(rawValues.length);
  for (int i = 0; i < rawValues.length; i++) {
    final value = rawValues[i];
    values[i] = value is num ? value.toDouble().clamp(0.0, 1.0) : 0.0;
  }

  if (values.length != width * height) {
    return null;
  }

  return DepthFrame(
    width: width,
    height: height,
    values: values,
    source: source,
  );
}
