import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

class YoloPrediction {
  const YoloPrediction({
    required this.classIndex,
    required this.confidence,
    required this.modelBox,
  });

  final int classIndex;
  final double confidence;
  final Rect modelBox;
}

class YoloOutputDecoder {
  const YoloOutputDecoder({
    required this.classCount,
    required this.inputWidth,
    required this.inputHeight,
    this.confidenceThreshold = 0.25,
    this.iouThreshold = 0.7,
    this.maxResults = 100,
  });

  final int classCount;
  final int inputWidth;
  final int inputHeight;
  final double confidenceThreshold;
  final double iouThreshold;
  final int maxResults;

  List<YoloPrediction> decode(Float32List output, List<int> outputShape) {
    if (outputShape.length != 3 || outputShape.first != 1) {
      throw StateError('Expected a three-dimensional YOLO output tensor.');
    }

    final featureCount = classCount + 4;
    final featuresFirst = outputShape[1] == featureCount;
    final anchorsFirst = outputShape[2] == featureCount;
    if (!featuresFirst && !anchorsFirst) {
      throw StateError(
        'YOLO output must contain four box values and $classCount classes.',
      );
    }

    final anchorCount = featuresFirst ? outputShape[2] : outputShape[1];
    if (output.length != featureCount * anchorCount) {
      throw StateError('YOLO output tensor has an unexpected element count.');
    }

    final candidates = <YoloPrediction>[];
    double valueAt(int feature, int anchor) {
      final index = featuresFirst
          ? feature * anchorCount + anchor
          : anchor * featureCount + feature;
      return output[index];
    }

    for (var anchor = 0; anchor < anchorCount; anchor += 1) {
      var classIndex = 0;
      var confidence = valueAt(4, anchor);
      for (var index = 1; index < classCount; index += 1) {
        final score = valueAt(index + 4, anchor);
        if (score > confidence) {
          confidence = score;
          classIndex = index;
        }
      }
      if (confidence < confidenceThreshold) {
        continue;
      }

      final centerX = valueAt(0, anchor);
      final centerY = valueAt(1, anchor);
      final width = valueAt(2, anchor);
      final height = valueAt(3, anchor);
      if (width <= 0 || height <= 0) {
        continue;
      }
      final box = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width,
        height: height,
      );
      if (box.right <= 0 ||
          box.bottom <= 0 ||
          box.left >= inputWidth ||
          box.top >= inputHeight) {
        continue;
      }
      candidates.add(
        YoloPrediction(
          classIndex: classIndex,
          confidence: confidence,
          modelBox: box,
        ),
      );
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <YoloPrediction>[];
    for (final candidate in candidates) {
      final overlaps = kept.any(
        (other) =>
            other.classIndex == candidate.classIndex &&
            _intersectionOverUnion(other.modelBox, candidate.modelBox) >
                iouThreshold,
      );
      if (!overlaps) {
        kept.add(candidate);
        if (kept.length == maxResults) {
          break;
        }
      }
    }
    return kept;
  }

  double _intersectionOverUnion(Rect a, Rect b) {
    final intersectionWidth = math.max(
      0.0,
      math.min(a.right, b.right) - math.max(a.left, b.left),
    );
    final intersectionHeight = math.max(
      0.0,
      math.min(a.bottom, b.bottom) - math.max(a.top, b.top),
    );
    final intersection = intersectionWidth * intersectionHeight;
    final union = a.width * a.height + b.width * b.height - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}
