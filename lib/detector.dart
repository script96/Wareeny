// Warene - cross-platform YOLOv8 detector.
//
// Runs TensorFlow Lite directly so the same detector works on Android and iOS.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class Detection {
  final String label;
  final String arabicLabel;
  final double confidence;
  final List<double> bbox; // [x1, y1, x2, y2] in original image coords

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
  final int imageWidth;
  final int imageHeight;

  DetectionResult({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });
}

enum DetectionModel { general, currency }

class _Candidate {
  final int classIndex;
  final double confidence;
  final List<double> bbox;

  const _Candidate({
    required this.classIndex,
    required this.confidence,
    required this.bbox,
  });
}

class YoloDetector {
  static const String _generalModelPath = 'assets/models/yolov8n.tflite';
  static const String _generalLabelsPath = 'assets/models/labels.txt';
  static const String _currencyModelPath =
      'assets/models/currency_yolov8n.tflite';
  static const String _currencyLabelsPath = 'assets/models/currency_labels.txt';
  static const int _maxDetections = 20;

  Interpreter? _interpreter;
  List<String> _labels = [];
  List<int> _inputShape = const [1, 640, 640, 3];
  List<int> _outputShape = const [1, 84, 8400];
  bool _isReady = false;

  bool get isReady => _isReady;

  static const Map<String, String> arabicNames = {
    'person': 'شَخْص',
    'bicycle': 'دَرَّاجَة',
    'car': 'سَيَّارَة',
    'motorcycle': 'دَرَّاجَة نَارِيَّة',
    'airplane': 'طَائِرَة',
    'bus': 'أُتُوبِيس',
    'train': 'قِطَار',
    'truck': 'شَاحِنَة',
    'boat': 'قَارِب',
    'traffic light': 'إِشَارَة مُرُور',
    'fire hydrant': 'صُنْبُور حَرِيق',
    'stop sign': 'لَافِتَة قِف',
    'parking meter': 'عَدَّاد مَوَاقِف',
    'bench': 'مَقْعَد',
    'bird': 'طَائِر',
    'cat': 'قِطَّة',
    'dog': 'كَلْب',
    'horse': 'حِصَان',
    'sheep': 'خَرُوف',
    'cow': 'بَقَرَة',
    'elephant': 'فِيل',
    'bear': 'دُبّ',
    'zebra': 'حِمَار وَحْشِيّ',
    'giraffe': 'زَرَافَة',
    'backpack': 'حَقِيبَة ظَهْر',
    'umbrella': 'شَمْسِيَّة',
    'handbag': 'حَقِيبَة يَد',
    'tie': 'رَبْطَة عُنُق',
    'suitcase': 'حَقِيبَة سَفَر',
    'frisbee': 'فَرِيسْبِي',
    'skis': 'تَزَلُّج',
    'snowboard': 'لَوْح تَزَلُّج',
    'sports ball': 'كُرَة',
    'kite': 'طَائِرَة وَرَقِيَّة',
    'baseball bat': 'مِضْرَب بِيسْبُول',
    'baseball glove': 'قُفَّاز بِيسْبُول',
    'skateboard': 'سْكِيتْبُورْد',
    'surfboard': 'لَوْح تَزَلُّج مَائِيّ',
    'tennis racket': 'مِضْرَب تِنِس',
    'bottle': 'زُجَاجَة',
    'wine glass': 'كَأْس',
    'cup': 'كُوب',
    'fork': 'شَوْكَة',
    'knife': 'سِكِّينَة',
    'spoon': 'مِلْعَقَة',
    'bowl': 'وِعَاء عَمِيق',
    'banana': 'مَوْزَة',
    'apple': 'تُفَّاحَة',
    'sandwich': 'سَانْدَوِتْش',
    'orange': 'بُرْتُقَالَة',
    'broccoli': 'بُرُوكْلِي',
    'carrot': 'جَزَرَة',
    'hot dog': 'هُوت دُوج',
    'pizza': 'بِيتْزَا',
    'donut': 'دُونَات',
    'cake': 'كَيْكَة',
    'chair': 'كُرْسِيّ',
    'couch': 'أَرِيكَة',
    'potted plant': 'نَبَات',
    'bed': 'سَرِير',
    'dining table': 'طَاوِلَة طَعَام',
    'toilet': 'مِرْحَاض',
    'tv': 'تِلِفِزْيُون',
    'laptop': 'لَابْتُوب',
    'mouse': 'فَأْرَة',
    'remote': 'جَهَاز تَحَكُّم',
    'keyboard': 'لَوْحَة مَفَاتِيح',
    'cell phone': 'هَاتِف',
    'microwave': 'مِيكْرُووِيف',
    'oven': 'فُرْن',
    'toaster': 'مَحْمَصَة',
    'sink': 'حَوْض',
    'refrigerator': 'ثَلَّاجَة',
    'book': 'كِتَاب',
    'clock': 'سَاعَة',
    'vase': 'مُزْهِرِيَّة',
    'scissors': 'مِقَصّ',
    'teddy bear': 'دُبْدُوب',
    'hair drier': 'سِشْوَار',
    'toothbrush': 'فُرْشَاة أَسْنَان',
  };

  static const Map<String, String> currencyArabicNames = {
    '0': 'عَشَرَة جُنَيْهَات',
    '1': 'خَمْسَة جُنَيْهَات',
    '10': 'خَمْسُونَ جُنَيْهًا',
    '11': 'عِشْرُونَ جُنَيْهًا',
    '12': 'خَمْسَة جُنَيْهَات',
    '13': 'مِائَة جُنَيْه',
    '2': 'مِائَة جُنَيْه',
    '3': 'عِشْرُونَ جُنَيْهًا',
    '4': 'مِائَتَا جُنَيْه',
    '5': 'مِائَتَا جُنَيْه',
    '6': 'خَمْسُونَ جُنَيْهًا',
    '7': 'عِشْرُونَ جُنَيْهًا',
    '8': 'خَمْسَة جُنَيْهَات',
    '9': 'مِائَة جُنَيْه',
  };

  DetectionModel _currentModel = DetectionModel.general;
  DetectionModel get currentModel => _currentModel;

  Future<void> loadModel(DetectionModel modelType) async {
    if (_isReady && _currentModel == modelType) return;

    _isReady = false;
    _interpreter?.close();
    _interpreter = null;
    _currentModel = modelType;

    try {
      final options = InterpreterOptions()..threads = 4;
      if (Platform.isAndroid) {
        options.addDelegate(XNNPackDelegate());
      }

      final modelPath = modelType == DetectionModel.general
          ? _generalModelPath
          : _currencyModelPath;
      final labelsPath = modelType == DetectionModel.general
          ? _generalLabelsPath
          : _currencyLabelsPath;

      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      final labelText = await rootBundle.loadString(labelsPath);
      _labels = labelText
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      _isReady = true;
    } catch (_) {
      _interpreter?.close();
      _interpreter = null;
      _isReady = false;
    }
  }

  Future<DetectionResult?> detectFromFile(String imagePath) async {
    final interpreter = _interpreter;
    if (!_isReady || interpreter == null) return null;

    try {
      final originalBytes = await File(imagePath).readAsBytes();
      return detectFromBytes(originalBytes);
    } catch (_) {
      return null;
    }
  }

  DetectionResult? detectFromBytes(Uint8List imageBytes) {
    final interpreter = _interpreter;
    if (!_isReady || interpreter == null) return null;

    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;

      final originalImage = img.bakeOrientation(decoded);
      final origW = originalImage.width;
      final origH = originalImage.height;

      final inputHeight = _inputShape[1];
      final inputWidth = _inputShape[2];
      final crop = _cropForModel(originalImage);
      final resized = img.copyResize(
        crop.image,
        width: inputWidth,
        height: inputHeight,
        interpolation: img.Interpolation.linear,
      );

      final input = _imageToInput(resized, inputWidth, inputHeight);
      final output = _createOutputBuffer(_outputShape);
      interpreter.run(input, output);

      final confidenceThreshold = _currentModel == DetectionModel.currency
          ? 0.15
          : 0.25;
      final iouThreshold = _currentModel == DetectionModel.currency
          ? 0.30
          : 0.45;
      final minBoxArea = _currentModel == DetectionModel.currency
          ? origW * origH * 0.002
          : origW * origH * 0.01;

      final candidates = _parseYoloOutput(
        output,
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        cropWidth: crop.image.width.toDouble(),
        cropHeight: crop.image.height.toDouble(),
        cropX: crop.x.toDouble(),
        cropY: crop.y.toDouble(),
        confidenceThreshold: confidenceThreshold,
        minBoxArea: minBoxArea,
      );

      final detections = _nonMaxSuppression(candidates, iouThreshold).map((
        candidate,
      ) {
        final label = candidate.classIndex < _labels.length
            ? _labels[candidate.classIndex]
            : 'object';
        final arabicLabel = _currentModel == DetectionModel.currency
            ? currencyArabicNames[label] ?? label
            : arabicNames[label] ?? label;
        return Detection(
          label: label,
          arabicLabel: arabicLabel,
          confidence: candidate.confidence,
          bbox: candidate.bbox,
        );
      }).toList();

      return DetectionResult(
        detections: detections,
        imageWidth: origW,
        imageHeight: origH,
      );
    } catch (_) {
      return null;
    }
  }

  _ModelCrop _cropForModel(img.Image originalImage) {
    if (_currentModel == DetectionModel.currency) {
      return _ModelCrop(image: originalImage, x: 0, y: 0);
    }

    final side = math.min(originalImage.width, originalImage.height);
    final cropX = ((originalImage.width - side) / 2).floor();
    final cropY = ((originalImage.height - side) / 2).floor();
    return _ModelCrop(
      image: img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: side,
        height: side,
      ),
      x: cropX,
      y: cropY,
    );
  }

  List<List<List<List<double>>>> _imageToInput(
    img.Image image,
    int width,
    int height,
  ) {
    return [
      List.generate(
        height,
        (y) => List.generate(width, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        }),
      ),
    ];
  }

  Object _createOutputBuffer(List<int> shape) {
    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0);
    }
    return List.generate(
      shape[0],
      (_) => _createOutputBuffer(shape.sublist(1)),
    );
  }

  List<_Candidate> _parseYoloOutput(
    Object output, {
    required int inputWidth,
    required int inputHeight,
    required double cropWidth,
    required double cropHeight,
    required double cropX,
    required double cropY,
    required double confidenceThreshold,
    required double minBoxArea,
  }) {
    if (_outputShape.length != 3 || _labels.isEmpty) return [];

    final raw = (output as List).first as List;
    final dim1 = _outputShape[1];
    final dim2 = _outputShape[2];
    final labelCount = _labels.length;
    final transposed = dim1 < dim2;
    final candidateCount = transposed ? dim2 : dim1;
    final attributeCount = transposed ? dim1 : dim2;
    final classStart = attributeCount == labelCount + 5 ? 5 : 4;
    final scaleX = cropWidth / inputWidth;
    final scaleY = cropHeight / inputHeight;
    final candidates = <_Candidate>[];

    double valueAt(int candidateIndex, int attributeIndex) {
      if (transposed) {
        return ((raw[attributeIndex] as List)[candidateIndex] as num)
            .toDouble();
      }
      return ((raw[candidateIndex] as List)[attributeIndex] as num).toDouble();
    }

    for (int i = 0; i < candidateCount; i++) {
      final objConfidence = classStart == 5
          ? valueAt(i, 4).clamp(0.0, 1.0)
          : 1.0;
      int bestClass = 0;
      double bestClassScore = 0;

      for (int c = 0; c < labelCount; c++) {
        final score = valueAt(i, classStart + c);
        if (score > bestClassScore) {
          bestClassScore = score;
          bestClass = c;
        }
      }

      final confidence = bestClassScore * objConfidence;
      if (confidence < confidenceThreshold) continue;

      final cx = valueAt(i, 0);
      final cy = valueAt(i, 1);
      final w = valueAt(i, 2);
      final h = valueAt(i, 3);
      final normalized = cx <= 1 && cy <= 1 && w <= 1 && h <= 1;
      final xScale = normalized ? cropWidth : scaleX;
      final yScale = normalized ? cropHeight : scaleY;

      final x1 = ((cx - w / 2) * xScale + cropX).clamp(0.0, double.infinity);
      final y1 = ((cy - h / 2) * yScale + cropY).clamp(0.0, double.infinity);
      final x2 = ((cx + w / 2) * xScale + cropX).clamp(0.0, double.infinity);
      final y2 = ((cy + h / 2) * yScale + cropY).clamp(0.0, double.infinity);
      final boxArea = (x2 - x1).abs() * (y2 - y1).abs();
      if (boxArea < minBoxArea) continue;

      candidates.add(
        _Candidate(
          classIndex: bestClass,
          confidence: confidence,
          bbox: [x1, y1, x2, y2],
        ),
      );
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates;
  }

  List<_Candidate> _nonMaxSuppression(
    List<_Candidate> candidates,
    double iouThreshold,
  ) {
    final selected = <_Candidate>[];
    final suppressed = List<bool>.filled(candidates.length, false);

    for (int i = 0; i < candidates.length; i++) {
      if (suppressed[i]) continue;
      final current = candidates[i];
      selected.add(current);
      if (selected.length >= _maxDetections) break;

      for (int j = i + 1; j < candidates.length; j++) {
        if (suppressed[j]) continue;
        if (current.classIndex == candidates[j].classIndex &&
            _iou(current.bbox, candidates[j].bbox) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return selected;
  }

  double _iou(List<double> a, List<double> b) {
    final left = math.max(a[0], b[0]);
    final top = math.max(a[1], b[1]);
    final right = math.min(a[2], b[2]);
    final bottom = math.min(a[3], b[3]);
    final intersection =
        math.max(0.0, right - left) * math.max(0.0, bottom - top);
    final areaA = math.max(0.0, a[2] - a[0]) * math.max(0.0, a[3] - a[1]);
    final areaB = math.max(0.0, b[2] - b[0]) * math.max(0.0, b[3] - b[1]);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isReady = false;
  }
}

class _ModelCrop {
  final img.Image image;
  final int x;
  final int y;

  const _ModelCrop({required this.image, required this.x, required this.y});
}
