import 'dart:typed_data';
import 'dart:ui';

import '../../data/models/detection.dart';
import '../../data/models/model_config.dart';

List<Detection> decodeDetections(
  Float32List output,
  int numBoxes,
  int numClasses,
  double confThreshold,
) {
  final expectedLength = (4 + numClasses) * numBoxes;
  if (output.length < expectedLength) {
    return [];
  }

  final inputSize = ModelConfig.inputSize.toDouble();
  final List<Detection> results = [];

  for (int i = 0; i < numBoxes; i++) {
    double maxScore = 0.0;
    int maxClassId = -1;

    for (int c = 0; c < numClasses; c++) {
      final score = output[(4 + c) * numBoxes + i];
      if (score > maxScore) {
        maxScore = score;
        maxClassId = c;
      }
    }

    if (maxScore < confThreshold || maxClassId < 0) {
      continue;
    }

    final xCenter = output[i] * inputSize;
    final yCenter = output[numBoxes + i] * inputSize;
    final w = output[2 * numBoxes + i] * inputSize;
    final h = output[3 * numBoxes + i] * inputSize;

    if (!xCenter.isFinite || !yCenter.isFinite || !w.isFinite || !h.isFinite) {
      continue;
    }

    double left = xCenter - w / 2;
    double top = yCenter - h / 2;
    double right = xCenter + w / 2;
    double bottom = yCenter + h / 2;

    left = left.clamp(0.0, inputSize).toDouble();
    top = top.clamp(0.0, inputSize).toDouble();
    right = right.clamp(0.0, inputSize).toDouble();
    bottom = bottom.clamp(0.0, inputSize).toDouble();

    final clampedWidth = right - left;
    final clampedHeight = bottom - top;

    if (clampedWidth <= 0 || clampedHeight <= 0) {
      continue;
    }

    results.add(
      Detection(
        rect: Rect.fromLTRB(left, top, right, bottom),
        classId: maxClassId,
        score: maxScore,
      ),
    );
  }

  return results;
}
