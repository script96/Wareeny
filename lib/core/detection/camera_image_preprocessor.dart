import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';

class YoloImageTransform {
  const YoloImageTransform({
    required this.imageWidth,
    required this.imageHeight,
    required this.inputWidth,
    required this.inputHeight,
    required this.gain,
    required this.padX,
    required this.padY,
  });

  final int imageWidth;
  final int imageHeight;
  final int inputWidth;
  final int inputHeight;
  final double gain;
  final double padX;
  final double padY;

  Rect normalizedImageBox(Rect modelBox) {
    final left = ((modelBox.left - padX) / gain / imageWidth).clamp(0.0, 1.0);
    final top = ((modelBox.top - padY) / gain / imageHeight).clamp(0.0, 1.0);
    final right = ((modelBox.right - padX) / gain / imageWidth).clamp(0.0, 1.0);
    final bottom = ((modelBox.bottom - padY) / gain / imageHeight).clamp(
      0.0,
      1.0,
    );
    return Rect.fromLTRB(
      math.min(left, right),
      math.min(top, bottom),
      math.max(left, right),
      math.max(top, bottom),
    );
  }
}

class CameraImagePreprocessor {
  const CameraImagePreprocessor();

  YoloImageTransform fillInput({
    required CameraImage image,
    required int rotationDegrees,
    required int inputWidth,
    required int inputHeight,
    required Float32List input,
  }) {
    if (input.length != inputWidth * inputHeight * 3) {
      throw ArgumentError('YOLO input buffer has an unexpected size.');
    }

    final rotation = _normalizeRotation(rotationDegrees);
    final swapsAxes = rotation == 90 || rotation == 270;
    final imageWidth = swapsAxes ? image.height : image.width;
    final imageHeight = swapsAxes ? image.width : image.height;
    final gain = math.min(inputWidth / imageWidth, inputHeight / imageHeight);
    final padX = (inputWidth - imageWidth * gain) / 2;
    final padY = (inputHeight - imageHeight * gain) / 2;
    final transform = YoloImageTransform(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      gain: gain,
      padX: padX,
      padY: padY,
    );

    input.fillRange(0, input.length, 114 / 255);
    final left = math.max(0, padX.floor());
    final top = math.max(0, padY.floor());
    final right = math.min(inputWidth, (padX + imageWidth * gain).ceil());
    final bottom = math.min(inputHeight, (padY + imageHeight * gain).ceil());

    for (var y = top; y < bottom; y += 1) {
      final orientedY = ((y + 0.5 - padY) / gain).floor().clamp(
        0,
        imageHeight - 1,
      );
      for (var x = left; x < right; x += 1) {
        final orientedX = ((x + 0.5 - padX) / gain).floor().clamp(
          0,
          imageWidth - 1,
        );
        final source = _sourcePoint(
          x: orientedX,
          y: orientedY,
          sourceWidth: image.width,
          sourceHeight: image.height,
          rotation: rotation,
        );
        final rgb = _readRgb(image, source.$1, source.$2);
        final offset = (y * inputWidth + x) * 3;
        input[offset] = rgb.$1 / 255;
        input[offset + 1] = rgb.$2 / 255;
        input[offset + 2] = rgb.$3 / 255;
      }
    }

    return transform;
  }

  int _normalizeRotation(int degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    if (normalized != 0 &&
        normalized != 90 &&
        normalized != 180 &&
        normalized != 270) {
      throw ArgumentError('Camera rotation must be a multiple of 90 degrees.');
    }
    return normalized;
  }

  (int, int) _sourcePoint({
    required int x,
    required int y,
    required int sourceWidth,
    required int sourceHeight,
    required int rotation,
  }) {
    return switch (rotation) {
      0 => (x, y),
      90 => (y, sourceHeight - 1 - x),
      180 => (sourceWidth - 1 - x, sourceHeight - 1 - y),
      270 => (sourceWidth - 1 - y, x),
      _ => throw StateError('Unsupported rotation.'),
    };
  }

  (int, int, int) _readRgb(CameraImage image, int x, int y) {
    return switch (image.format.group) {
      ImageFormatGroup.bgra8888 => _readBgra(image, x, y),
      ImageFormatGroup.yuv420 => _readYuv420(image, x, y),
      ImageFormatGroup.nv21 => _readNv21(image, x, y),
      _ => throw UnsupportedError(
        'Unsupported camera format: ${image.format.group.name}',
      ),
    };
  }

  (int, int, int) _readBgra(CameraImage image, int x, int y) {
    final plane = image.planes.first;
    final offset = y * plane.bytesPerRow + x * (plane.bytesPerPixel ?? 4);
    return (
      plane.bytes[offset + 2],
      plane.bytes[offset + 1],
      plane.bytes[offset],
    );
  }

  (int, int, int) _readYuv420(CameraImage image, int x, int y) {
    if (image.planes.length < 3) {
      throw UnsupportedError('Expected three YUV420 camera planes.');
    }
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yValue = yPlane.bytes[y * yPlane.bytesPerRow + x];
    final uvX = x ~/ 2;
    final uvY = y ~/ 2;
    final uValue = uPlane
        .bytes[uvY * uPlane.bytesPerRow + uvX * (uPlane.bytesPerPixel ?? 1)];
    final vValue = vPlane
        .bytes[uvY * vPlane.bytesPerRow + uvX * (vPlane.bytesPerPixel ?? 1)];
    return _yuvToRgb(yValue, uValue, vValue);
  }

  (int, int, int) _readNv21(CameraImage image, int x, int y) {
    final bytes = image.planes.first.bytes;
    final frameSize = image.width * image.height;
    final yValue = bytes[y * image.width + x];
    final uvOffset = frameSize + (y ~/ 2) * image.width + (x & ~1);
    return _yuvToRgb(yValue, bytes[uvOffset + 1], bytes[uvOffset]);
  }

  (int, int, int) _yuvToRgb(int y, int u, int v) {
    final luminance = 1.164 * (y - 16);
    final uOffset = u - 128;
    final vOffset = v - 128;
    return (
      (luminance + 1.596 * vOffset).round().clamp(0, 255),
      (luminance - 0.392 * uOffset - 0.813 * vOffset).round().clamp(0, 255),
      (luminance + 2.017 * uOffset).round().clamp(0, 255),
    );
  }
}
