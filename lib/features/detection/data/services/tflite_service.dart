import 'dart:typed_data';

import '../../../../data/models/detection.dart';
import '../../../../data/models/model_config.dart';
import '../isolates/inference_isolate.dart';

class TfliteService {
  final InferenceIsolate _isolate = InferenceIsolate();

  Future<void>? _initializing;
  bool _disposed = false;
  String _modelPath = ModelConfig.modelAssetPath;

  Future<void> initialize({String? modelPath}) async {
    if (_disposed) {
      throw StateError('TfliteService has been disposed.');
    }

    final targetPath = modelPath ?? _modelPath;

    if (_isolate.isReady && _modelPath == targetPath) return;

    if (_isolate.isReady) {
      _isolate.dispose();
    }

    _modelPath = targetPath;
    _initializing = _isolate.init(_modelPath);
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
    String? modelPath,
  }) async {
    if (_disposed) {
      throw StateError('TfliteService has been disposed.');
    }

    try {
      await initialize(modelPath: modelPath);
      return await _isolate.runInference(
        InferenceRequest(
          imageBytes: imageBytes,
          confidenceThreshold: confidenceThreshold,
          iouThreshold: iouThreshold,
        ),
      );
    } catch (e) {
      // Tự động khôi phục isolate khi gặp lỗi hoặc timeout bằng cách giải phóng tài nguyên lỗi
      _isolate.dispose();
      _initializing = null;
      rethrow;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isolate.dispose();
  }
}
