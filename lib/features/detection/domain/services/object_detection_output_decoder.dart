import 'dart:typed_data';

import '../../../../data/models/detection.dart';

abstract class ObjectDetectionOutputDecoder {
  List<Detection> decode({
    required Float32List boxes,
    required Float32List scores,
    required int numBoxes,
    required int numClasses,
    required double confidenceThreshold,
  });
}
