import 'dart:typed_data';
import '../../../../data/models/detection.dart';

abstract class Detector {
  bool get isReady;
  
  Future<void> initialize();
  
  Future<List<Detection>> detect(
    Uint8List imageBytes, {
    double confidenceThreshold,
    double iouThreshold,
  });
  
  Future<void> dispose();
}
