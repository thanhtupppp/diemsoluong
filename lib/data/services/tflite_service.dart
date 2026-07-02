import 'dart:typed_data';

import '../../core/isolate/inference_isolate.dart';
import '../../data/models/detection.dart';
import '../../data/models/model_config.dart';

class TfliteService {
  final InferenceIsolate _isolate = InferenceIsolate();

  Future<void>? _initializing;
  bool _disposed = false;

  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('TfliteService has been disposed.');
    }

    if (_isolate.isReady) return;

    _initializing ??= _isolate.init();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<List<Detection>> detectObjects(
    Uint8List imageBytes, {
    double confidenceThreshold = ModelConfig.defaultConfidenceThreshold,
    double iouThreshold = ModelConfig.defaultIouThreshold,
  }) async {
    if (_disposed) {
      throw StateError('TfliteService has been disposed.');
    }

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
    if (_disposed) return;
    _disposed = true;
    _isolate.dispose();
  }
}
