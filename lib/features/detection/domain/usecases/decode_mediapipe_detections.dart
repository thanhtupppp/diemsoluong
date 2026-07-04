import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../../../../data/models/detection.dart';
import '../../../../data/models/model_config.dart';
import '../services/object_detection_output_decoder.dart';

enum ScoreActivation { none, sigmoid, softmax }

class EfficientDetAnchor {
  final double xCenter;
  final double yCenter;
  final double width;
  final double height;

  const EfficientDetAnchor({
    required this.xCenter,
    required this.yCenter,
    required this.width,
    required this.height,
  });
}

List<EfficientDetAnchor> buildEfficientDetAnchors({
  int inputSize = ModelConfig.inputSize,
  int minLevel = 3,
  int maxLevel = 7,
  int numScales = 3,
  double anchorScale = 4.0,
  List<double> aspectRatios = const [1.0, 2.0, 0.5],
}) {
  final anchors = <EfficientDetAnchor>[];

  for (int level = minLevel; level <= maxLevel; level++) {
    final stride = 1 << level;
    final featureSize = (inputSize / stride).ceil();

    for (int y = 0; y < featureSize; y++) {
      for (int x = 0; x < featureSize; x++) {
        final yCenter = (y + 0.5) * stride / inputSize;
        final xCenter = (x + 0.5) * stride / inputSize;

        for (int scaleIndex = 0; scaleIndex < numScales; scaleIndex++) {
          final scale = pow(2.0, scaleIndex / numScales).toDouble();
          final anchorSize = anchorScale * stride * scale / inputSize;

          for (final aspectRatio in aspectRatios) {
            final ratioSqrt = sqrt(aspectRatio);
            anchors.add(
              EfficientDetAnchor(
                xCenter: xCenter,
                yCenter: yCenter,
                width: anchorSize * ratioSqrt,
                height: anchorSize / ratioSqrt,
              ),
            );
          }
        }
      }
    }
  }

  return anchors;
}

List<Detection> decodeMediaPipeDetections({
  required Float32List boxes,
  required Float32List scores,
  required int numBoxes,
  required int numClasses,
  required double confidenceThreshold,
  required List<EfficientDetAnchor> anchors,
  int inputSize = ModelConfig.inputSize,
  Set<int>? allowedClassIds,
  ScoreActivation scoreActivation = ScoreActivation.none,
  DetectionDebugLog? debugLog,
}) {
  if (boxes.length < numBoxes * 4 ||
      scores.length < numBoxes * numClasses ||
      anchors.length < numBoxes) {
    debugLog?.call(
      'MediaPipe EfficientDet decoder shape mismatch: '
      'boxes.length=${boxes.length}, scores.length=${scores.length}, '
      'anchors.length=${anchors.length}, numBoxes=$numBoxes, '
      'numClasses=$numClasses.',
    );
    return [];
  }

  const yScale = 10.0;
  const xScale = 10.0;
  const hScale = 5.0;
  const wScale = 5.0;

  final inputSizeDouble = inputSize.toDouble();
  final detections = <Detection>[];
  final softmaxBuffer = scoreActivation == ScoreActivation.softmax
      ? Float32List(numClasses)
      : null;

  for (int i = 0; i < numBoxes; i++) {
    double bestScore = 0.0;
    int bestClassId = -1;

    final scoreOffset = i * numClasses;

    if (softmaxBuffer != null) {
      _fillSoftmaxScores(scores, scoreOffset, numClasses, softmaxBuffer);
    }

    for (int c = 0; c < numClasses; c++) {
      if (allowedClassIds != null && !allowedClassIds.contains(c)) {
        continue;
      }

      final score = switch (scoreActivation) {
        ScoreActivation.none => scores[scoreOffset + c],
        ScoreActivation.sigmoid => _sigmoid(scores[scoreOffset + c]),
        ScoreActivation.softmax => softmaxBuffer![c],
      };

      if (score > bestScore) {
        bestScore = score;
        bestClassId = c;
      }
    }

    if (bestScore < confidenceThreshold || bestClassId < 0) {
      continue;
    }

    final anchor = anchors[i];
    final boxOffset = i * 4;
    final yCenter = boxes[boxOffset] / yScale * anchor.height + anchor.yCenter;
    final xCenter =
        boxes[boxOffset + 1] / xScale * anchor.width + anchor.xCenter;
    final height = exp(boxes[boxOffset + 2] / hScale) * anchor.height;
    final width = exp(boxes[boxOffset + 3] / wScale) * anchor.width;

    final ymin = (yCenter - height / 2).clamp(0.0, 1.0).toDouble();
    final xmin = (xCenter - width / 2).clamp(0.0, 1.0).toDouble();
    final ymax = (yCenter + height / 2).clamp(0.0, 1.0).toDouble();
    final xmax = (xCenter + width / 2).clamp(0.0, 1.0).toDouble();

    if (xmax <= xmin || ymax <= ymin) {
      continue;
    }

    detections.add(
      Detection(
        rect: Rect.fromLTRB(
          xmin * inputSizeDouble,
          ymin * inputSizeDouble,
          xmax * inputSizeDouble,
          ymax * inputSizeDouble,
        ),
        classId: bestClassId,
        score: bestScore,
      ),
    );
  }

  return detections;
}

double _sigmoid(double value) {
  if (value >= 0) {
    final z = exp(-value);
    return 1.0 / (1.0 + z);
  }
  final z = exp(value);
  return z / (1.0 + z);
}

void _fillSoftmaxScores(
  Float32List scores,
  int scoreOffset,
  int numClasses,
  Float32List output,
) {
  double maxLogit = double.negativeInfinity;
  for (int c = 0; c < numClasses; c++) {
    final value = scores[scoreOffset + c];
    if (value > maxLogit) {
      maxLogit = value;
    }
  }

  double sum = 0.0;
  for (int c = 0; c < numClasses; c++) {
    final value = exp(scores[scoreOffset + c] - maxLogit);
    output[c] = value;
    sum += value;
  }

  if (sum <= 0 || !sum.isFinite) {
    for (int c = 0; c < numClasses; c++) {
      output[c] = 0.0;
    }
    return;
  }

  for (int c = 0; c < numClasses; c++) {
    output[c] = output[c] / sum;
  }
}

class MediaPipeEfficientDetOutputDecoder
    implements ObjectDetectionOutputDecoder {
  final int inputSize;
  final List<EfficientDetAnchor> anchors;
  final ScoreActivation scoreActivation;

  MediaPipeEfficientDetOutputDecoder({
    required this.inputSize,
    List<EfficientDetAnchor>? anchors,
    this.scoreActivation = ScoreActivation.none,
  }) : anchors = anchors ?? buildEfficientDetAnchors(inputSize: inputSize);

  @override
  List<Detection> decode({
    required Float32List boxes,
    required Float32List scores,
    required int numBoxes,
    required int numClasses,
    required double confidenceThreshold,
    Set<int>? allowedClassIds,
    DetectionDebugLog? debugLog,
  }) {
    return decodeMediaPipeDetections(
      boxes: boxes,
      scores: scores,
      numBoxes: numBoxes,
      numClasses: numClasses,
      confidenceThreshold: confidenceThreshold,
      anchors: anchors,
      inputSize: inputSize,
      allowedClassIds: allowedClassIds,
      scoreActivation: scoreActivation,
      debugLog: debugLog,
    );
  }
}
