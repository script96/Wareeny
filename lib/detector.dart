import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// ── Serializable payload sent to the preprocessing isolate ──────────
class _PreprocessRequest {
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int imgWidth;
  final int imgHeight;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  _PreprocessRequest({
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.imgWidth,
    required this.imgHeight,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });
}

// ── Top-level function — runs inside an isolate ─────────────────────
Float32List _preprocessYuv420Isolate(_PreprocessRequest req) {
  const int size = 640;
  final int srcW = req.imgWidth;
  final int srcH = req.imgHeight;

  final yBytes = req.yBytes;
  final uBytes = req.uBytes;
  final vBytes = req.vBytes;
  final int yRow = req.yRowStride;
  final int uvRow = req.uvRowStride;
  final int uvPx = req.uvPixelStride;

  final Float32List out = Float32List(1 * size * size * 3);

  for (int y = 0; y < size; y++) {
    final int srcY = (y * srcH) ~/ size;
    final int yRowOffset = srcY * yRow;
    final int uvRowOffset = (srcY >> 1) * uvRow;

    for (int x = 0; x < size; x++) {
      final int srcX = (x * srcW) ~/ size;
      final int uvColOffset = (srcX >> 1) * uvPx;

      final int yVal = yBytes[yRowOffset + srcX];
      final int uVal = uBytes[uvRowOffset + uvColOffset];
      final int vVal = vBytes[uvRowOffset + uvColOffset];

      int r = (yVal + 1.402 * (vVal - 128)).round();
      int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).round();
      int b = (yVal + 1.772 * (uVal - 128)).round();

      if (r < 0) r = 0; if (r > 255) r = 255;
      if (g < 0) g = 0; if (g > 255) g = 255;
      if (b < 0) b = 0; if (b > 255) b = 255;

      final int idx = (y * size + x) * 3;
      out[idx]     = r / 255.0;
      out[idx + 1] = g / 255.0;
      out[idx + 2] = b / 255.0;
    }
  }

  return out;
}

// ── Main detector class ─────────────────────────────────────────────
class YoloDetector {
  Interpreter? _interpreter;
  bool _isReady = false;

  bool get isReady => _isReady;

  static const List<String> classNames = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
    'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
    'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep',
    'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella',
    'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard',
    'sports ball', 'kite', 'baseball bat', 'baseball glove', 'skateboard',
    'surfboard', 'tennis racket', 'bottle', 'wine glass', 'cup', 'fork',
    'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange',
    'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair',
    'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv',
    'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave',
    'oven', 'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase',
    'scissors', 'teddy bear', 'hair drier', 'toothbrush',
  ];

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
    print('🔵 Starting model load...');
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov8n.tflite',
        options: options,
      );
      _isReady = true;
      print('✅ YOLOv8 model loaded');
      print('✅ Input:  ${_interpreter!.getInputTensor(0).shape}');
      print('✅ Output: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('❌ Model load error: $e');
      _isReady = false;
    }
  }

  Future<List<Detection>> detect(CameraImage image) async {
    if (!_isReady || _interpreter == null) return [];

    try {
      // 1. Copy plane bytes
      final request = _PreprocessRequest(
        yBytes: Uint8List.fromList(image.planes[0].bytes),
        uBytes: Uint8List.fromList(image.planes[1].bytes),
        vBytes: Uint8List.fromList(image.planes[2].bytes),
        imgWidth: image.width,
        imgHeight: image.height,
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      );

      // 2. Preprocess in background isolate
      final Float32List preprocessed =
          await Isolate.run(() => _preprocessYuv420Isolate(request));

      // 3. Reshape to 4D list
      const int size = 640;
      final input = List.generate(
        1,
        (_) => List.generate(
          size,
          (y) => List.generate(
            size,
            (x) {
              final int base = (y * size + x) * 3;
              return [
                preprocessed[base],
                preprocessed[base + 1],
                preprocessed[base + 2],
              ];
            },
          ),
        ),
      );

      // 4. Output buffer
      final output = [
        List.generate(84, (_) => List.filled(8400, 0.0)),
      ];

      // 5. Run inference
      _interpreter!.run(input, output);

      // 6. Parse output
      return _parseOutput(output[0]);
    } catch (e) {
      print('❌ Detection error: $e');
      return [];
    }
  }

  List<Detection> _parseOutput(List<List<double>> output) {
    const double confThreshold = 0.45;
    final List<Detection> raw = [];

    for (int i = 0; i < 8400; i++) {
      double maxScore = 0;
      int classId = 0;

      for (int c = 4; c < 84; c++) {
        if (output[c][i] > maxScore) {
          maxScore = output[c][i];
          classId = c - 4;
        }
      }

      if (maxScore > confThreshold) {
        raw.add(Detection(
          classId: classId,
          confidence: maxScore,
          bbox: [output[0][i], output[1][i], output[2][i], output[3][i]],
          label: classId < classNames.length
              ? classNames[classId]
              : 'unknown',
          arabicLabel: classId < classNames.length
              ? (arabicNames[classNames[classId]] ?? classNames[classId])
              : 'شيء',
        ));
      }
    }

    raw.sort((a, b) => b.confidence.compareTo(a.confidence));
    return _nms(raw, 0.5);
  }

  List<Detection> _nms(List<Detection> dets, double iouThreshold) {
    final List<Detection> keep = [];
    for (final det in dets) {
      bool suppressed = false;
      for (final kept in keep) {
        if (det.classId == kept.classId &&
            _iou(det.bbox, kept.bbox) > iouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) keep.add(det);
    }
    return keep;
  }

  double _iou(List<double> a, List<double> b) {
    final double ax1 = a[0] - a[2] / 2, ay1 = a[1] - a[3] / 2;
    final double ax2 = a[0] + a[2] / 2, ay2 = a[1] + a[3] / 2;
    final double bx1 = b[0] - b[2] / 2, by1 = b[1] - b[3] / 2;
    final double bx2 = b[0] + b[2] / 2, by2 = b[1] + b[3] / 2;

    final double ix1 = ax1 > bx1 ? ax1 : bx1;
    final double iy1 = ay1 > by1 ? ay1 : by1;
    final double ix2 = ax2 < bx2 ? ax2 : bx2;
    final double iy2 = ay2 < by2 ? ay2 : by2;

    final double iw = (ix2 - ix1) > 0 ? (ix2 - ix1) : 0;
    final double ih = (iy2 - iy1) > 0 ? (iy2 - iy1) : 0;
    final double inter = iw * ih;

    final double aArea = a[2] * a[3];
    final double bArea = b[2] * b[3];
    final double union = aArea + bArea - inter;

    return union > 0 ? inter / union : 0;
  }

  void dispose() {
    _interpreter?.close();
  }
}

// ── Detection result ────────────────────────────────────────────────
class Detection {
  final int classId;
  final double confidence;
  final List<double> bbox;
  final String label;
  final String arabicLabel;

  Detection({
    required this.classId,
    required this.confidence,
    required this.bbox,
    required this.label,
    required this.arabicLabel,
  });
}