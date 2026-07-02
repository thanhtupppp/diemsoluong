import 'dart:typed_data';

import '../../../../data/models/detection.dart';
import '../../domain/services/detector.dart';
import '../services/tflite_service.dart';

class TfliteDetector implements Detector {
  final TfliteService _tfliteService = TfliteService();

  @override
  bool get isReady => true; // Isolate initialization is handled dynamically inside the service

  @override
  Future<void> initialize() async {
    await _tfliteService.initialize();
  }

  @override
  Future<List<Detection>> detect(
    Uint8List imageBytes, {
    double? confidenceThreshold,
    double? iouThreshold,
  }) async {
    // If thresholds are not specified, TfliteService falls back to default values from ModelConfig
    if (confidenceThreshold != null && iouThreshold != null) {
      return _tfliteService.detectObjects(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );
    } else if (confidenceThreshold != null) {
      return _tfliteService.detectObjects(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
      );
    } else if (iouThreshold != null) {
      return _tfliteService.detectObjects(
        imageBytes,
        iouThreshold: iouThreshold,
      );
    } else {
      return _tfliteService.detectObjects(imageBytes);
    }
  }

  @override
  Future<void> dispose() async {
    _tfliteService.dispose();
  }
}
