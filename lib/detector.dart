// Warene — YoloDetector wrapper for flutter_vision
//
// Uses yoloOnImage() with JPEG bytes to bypass flutter_vision's
// broken YUV stride-padding handling in yoloOnFrame().
// Center-crops portrait images to square before inference
// to avoid aspect-ratio distortion that kills accuracy.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_vision/flutter_vision.dart';

// ── Detection result ────────────────────────────────────────────────
class Detection {
  final String label;
  final String arabicLabel;
  final double confidence;
  final List<double> bbox;  // [x1, y1, x2, y2] in ORIGINAL image coords

  Detection({
    required this.label,
    required this.arabicLabel,
    required this.confidence,
    required this.bbox,
  });

  @override
  String toString() =>
      'Detection($arabicLabel / $label, ${(confidence * 100).toStringAsFixed(0)}%)';
}

class DetectionResult {
  final List<Detection> detections;
  final int imageWidth;   // original image width
  final int imageHeight;  // original image height

  DetectionResult({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });
}

// ── Main detector class ─────────────────────────────────────────────
class YoloDetector {
  final FlutterVision _vision = FlutterVision();
  bool _isReady = false;

  bool get isReady => _isReady;

  static const Map<String, String> arabicNames = {
    'person': 'شخص',
    'bicycle': 'دراجة',
    'car': 'سيارة',
    'motorcycle': 'دراجة نارية',
    'airplane': 'طائرة',
    'bus': 'أتوبيس',
    'train': 'قطار',
    'truck': 'شاحنة',
    'boat': 'قارب',
    'traffic light': 'إشارة مرور',
    'fire hydrant': 'صنبور حريق',
    'stop sign': 'لافتة قف',
    'parking meter': 'عداد مواقف',
    'bench': 'مقعد',
    'bird': 'طائر',
    'cat': 'قطة',
    'dog': 'كلب',
    'horse': 'حصان',
    'sheep': 'خروف',
    'cow': 'بقرة',
    'elephant': 'فيل',
    'bear': 'دب',
    'zebra': 'حمار وحشي',
    'giraffe': 'زرافة',
    'backpack': 'حقيبة ظهر',
    'umbrella': 'شمسية',
    'handbag': 'حقيبة يد',
    'tie': 'كرافتة',
    'suitcase': 'شنطة سفر',
    'frisbee': 'فريسبي',
    'skis': 'تزلج',
    'snowboard': 'لوح تزلج',
    'sports ball': 'كرة',
    'kite': 'طائرة ورقية',
    'baseball bat': 'مضرب بيسبول',
    'baseball glove': 'قفاز بيسبول',
    'skateboard': 'سكيتبورد',
    'surfboard': 'لوح تزلج مائي',
    'tennis racket': 'مضرب تنس',
    'bottle': 'زجاجة',
    'wine glass': 'كأس',
    'cup': 'كوب',
    'fork': 'شوكة',
    'knife': 'سكينة',
    'spoon': 'معلقة',
    'bowl': 'طبق عميق',
    'banana': 'موزة',
    'apple': 'تفاحة',
    'sandwich': 'ساندوتش',
    'orange': 'برتقالة',
    'broccoli': 'بروكلي',
    'carrot': 'جزرة',
    'hot dog': 'هوت دوج',
    'pizza': 'بيتزا',
    'donut': 'دونات',
    'cake': 'كيكة',
    'chair': 'كرسي',
    'couch': 'أريكة',
    'potted plant': 'نبات',
    'bed': 'سرير',
    'dining table': 'طاولة طعام',
    'toilet': 'حمام',
    'tv': 'تلفزيون',
    'laptop': 'لابتوب',
    'mouse': 'ماوس',
    'remote': 'ريموت',
    'keyboard': 'لوحة مفاتيح',
    'cell phone': 'هاتف',
    'microwave': 'ميكروويف',
    'oven': 'فرن',
    'toaster': 'محمصة',
    'sink': 'حوض',
    'refrigerator': 'ثلاجة',
    'book': 'كتاب',
    'clock': 'ساعة',
    'vase': 'مزهرية',
    'scissors': 'مقص',
    'teddy bear': 'دبدوب',
    'hair drier': 'سشوار',
    'toothbrush': 'فرشة سنان',
  };

  Future<void> loadModel() async {
    print('🔵 Loading YOLOv8 model via flutter_vision...');
    try {
      await _vision.loadYoloModel(
        labels: 'assets/models/labels.txt',
        modelPath: 'assets/models/yolov8n.tflite',
        modelVersion: 'yolov8',
        quantization: false,
        numThreads: 4,
        useGpu: false,
      );
      _isReady = true;
      print('✅ YOLOv8 model loaded');
    } catch (e) {
      print('❌ Model load error: $e');
      _isReady = false;
    }
  }

  /// Center-crop image to square (preserves aspect ratio for model).
  ///
  /// A 720x1280 portrait image squished to 640x640 distorts objects
  /// and kills accuracy. Center-cropping to 720x720 first means the
  /// model only needs to mildly downscale — much better detection.
  Future<Uint8List?> _centerCropToSquare(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      final w = srcImage.width;
      final h = srcImage.height;

      // Already square (or close enough)
      if ((w - h).abs() < 10) {
        srcImage.dispose();
        codec.dispose();
        return null; // signal: use original
      }

      final side = math.min(w, h);
      final cropX = (w - side) / 2;
      final cropY = (h - side) / 2;

      // Draw center crop to new canvas
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        srcImage,
        ui.Rect.fromLTWH(cropX, cropY, side.toDouble(), side.toDouble()),
        ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
        ui.Paint(),
      );
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(side, side);

      // Encode as PNG
      final byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      srcImage.dispose();
      croppedImage.dispose();
      picture.dispose();
      codec.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('⚠️ Center crop failed: $e');
      return null;
    }
  }

  /// Run YOLOv8 detection on a JPEG image file.
  ///
  /// Center-crops to square first for better accuracy,
  /// then maps coordinates back to original image space.
  Future<DetectionResult?> detectFromFile(String imagePath) async {
    if (!_isReady) return null;

    try {
      final Uint8List originalBytes = await File(imagePath).readAsBytes();

      // Get original image dimensions.
      final origCodec = await ui.instantiateImageCodec(originalBytes);
      final origFrame = await origCodec.getNextFrame();
      final int origW = origFrame.image.width;
      final int origH = origFrame.image.height;
      origFrame.image.dispose();
      origCodec.dispose();

      // Center-crop to square for better accuracy.
      final int side = math.min(origW, origH);
      final double cropX = (origW - side) / 2;
      final double cropY = (origH - side) / 2;

      Uint8List inferenceBytes;
      int inferenceW, inferenceH;

      final cropped = await _centerCropToSquare(originalBytes);
      if (cropped != null) {
        inferenceBytes = cropped;
        inferenceW = side;
        inferenceH = side;
        print('📷 Cropped ${origW}x$origH → ${side}x$side');
      } else {
        inferenceBytes = originalBytes;
        inferenceW = origW;
        inferenceH = origH;
        print('📷 Image ${origW}x$origH (already square)');
      }

      // Run inference on the (cropped) image.
      final results = await _vision.yoloOnImage(
        bytesList: inferenceBytes,
        imageHeight: inferenceH,
        imageWidth: inferenceW,
        iouThreshold: 0.4,
        confThreshold: 0.25,
        classThreshold: 0.25,
      );

      print('🔍 Detections: ${results.length}');

      if (results.isEmpty) {
        return DetectionResult(
          detections: [],
          imageWidth: origW,
          imageHeight: origH,
        );
      }

      // Convert detections — map from cropped coords back to original.
      // Also filter out tiny boxes (< 1% of image area) that are usually noise.
      final double minBoxArea = origW * origH * 0.01;

      final detections = <Detection>[];
      for (final result in results) {
        final String tag = result['tag'] as String;
        final List<dynamic> box = result['box'] as List<dynamic>;
        final double confidence = (box[4] as num).toDouble();

        // Coordinates are in cropped-image space.
        // Add crop offset to get original-image coordinates.
        final double x1 = (box[0] as num).toDouble() + cropX;
        final double y1 = (box[1] as num).toDouble() + cropY;
        final double x2 = (box[2] as num).toDouble() + cropX;
        final double y2 = (box[3] as num).toDouble() + cropY;

        // Skip tiny boxes — likely noise or background patches.
        final double boxArea = (x2 - x1).abs() * (y2 - y1).abs();
        if (boxArea < minBoxArea) continue;

        detections.add(Detection(
          label: tag,
          arabicLabel: arabicNames[tag] ?? tag,
          confidence: confidence,
          bbox: [x1, y1, x2, y2],
        ));
      }

      detections.sort((a, b) => b.confidence.compareTo(a.confidence));

      return DetectionResult(
        detections: detections,
        imageWidth: origW,
        imageHeight: origH,
      );
    } catch (e) {
      print('❌ Detection error: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      await _vision.closeYoloModel();
    } catch (_) {}
  }
}