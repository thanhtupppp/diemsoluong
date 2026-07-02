import 'dart:typed_data';
import '../../core/isolate/inference_isolate.dart';
import '../../data/models/detection.dart';
import '../../data/models/model_config.dart';

class TfliteService {
  final InferenceIsolate _isolate = InferenceIsolate();

  Future<void> initialize() async {
    if (!_isolate.isReady) {
      await _isolate.init();
    }
  }

  Future<List<Detection>> detectObjects(
    Uint8List imageBytes, {
    double confidenceThreshold = ModelConfig.defaultConfidenceThreshold,
    double iouThreshold = ModelConfig.defaultIouThreshold,
  }) async {
    await initialize();
    return _isolate.runInference(
      InferenceRequest(
        imageBytes: imageBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      ),
    );
  }

  void dispose() {
    _isolate.dispose();
  }
}
