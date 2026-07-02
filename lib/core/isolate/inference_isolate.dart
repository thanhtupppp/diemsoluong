import 'dart:isolate';
// ignore: unnecessary_import
import 'dart:typed_data';
// ignore: unnecessary_import
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../data/models/detection.dart';
import '../../data/models/model_config.dart';
import '../../data/services/image_service.dart';
import '../../domain/usecases/decode_yolo_output.dart';
import '../../domain/usecases/nms_filter.dart';

class InferenceRequest {
  final Uint8List imageBytes;
  final double confidenceThreshold;
  final double iouThreshold;

  InferenceRequest({
    required this.imageBytes,
    required this.confidenceThreshold,
    required this.iouThreshold,
  });
}

class InferenceIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> init() async {
    final token = RootIsolateToken.instance!;
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      [_receivePort.sendPort, token],
    );
    _isolate = isolate;

    _sendPort = await _receivePort.first as SendPort;
    _isReady = true;
  }

  Future<List<Detection>> runInference(InferenceRequest request) async {
    if (!_isReady || _sendPort == null) {
      throw StateError('InferenceIsolate is not ready.');
    }
    final responsePort = ReceivePort();
    try {
      _sendPort!.send([request, responsePort.sendPort]);
      final result = await responsePort.first as List<Detection>;
      return result;
    } finally {
      responsePort.close();
    }
  }

  void dispose() {
    _isReady = false;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _receivePort.close();
  }

  static void _isolateEntryPoint(List<dynamic> args) async {
    final mainSendPort = args[0] as SendPort;
    final token = args[1] as RootIsolateToken;

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    // Khởi tạo interpreter tflite trong Isolate phụ
    final options = InterpreterOptions()..threads = 4;
    options.useNnApiForAndroid = true;

    final interpreter = await Interpreter.fromAsset(
      ModelConfig.modelAssetPath,
      options: options,
    );

    // Cache kích thước output tensor
    final outputShape = interpreter.getOutputTensors().first.shape;
    final numClasses = outputShape[1] - 4;
    final numBoxes = outputShape[2];

    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    commandPort.listen((message) async {
      final request = message[0] as InferenceRequest;
      final replyPort = message[1] as SendPort;

      try {
        // 1. Tiền xử lý ảnh sang PreprocessResult
        final preprocessResult = ImageService.preprocessImage(
          request.imageBytes,
          ModelConfig.inputSize,
        );

        if (preprocessResult == null) {
          replyPort.send(<Detection>[]);
          return;
        }

        final outputBuffer = Float32List(1 * (4 + numClasses) * numBoxes);

        // 2. Chạy mô hình
        interpreter.run(
          preprocessResult.input.reshape([1, ModelConfig.inputSize, ModelConfig.inputSize, 3]),
          outputBuffer.reshape([1, 4 + numClasses, numBoxes]),
        );

        // 3. Giải mã
        final decoded = decodeDetections(
          outputBuffer,
          numBoxes,
          numClasses,
          request.confidenceThreshold,
        );

        // Ánh xạ ngược tọa độ từ model space về original image space (unletterbox)
        final scale = preprocessResult.scale;
        final padX = preprocessResult.padX;
        final padY = preprocessResult.padY;
        final origW = preprocessResult.originalWidth.toDouble();
        final origH = preprocessResult.originalHeight.toDouble();

        final unletterboxed = decoded.map((det) {
          final rect = det.rect;
          double left = (rect.left - padX) / scale;
          double top = (rect.top - padY) / scale;
          double right = (rect.right - padX) / scale;
          double bottom = (rect.bottom - padY) / scale;

          left = left.clamp(0.0, origW).toDouble();
          top = top.clamp(0.0, origH).toDouble();
          right = right.clamp(0.0, origW).toDouble();
          bottom = bottom.clamp(0.0, origH).toDouble();

          return Detection(
            rect: Rect.fromLTRB(left, top, right, bottom),
            classId: det.classId,
            score: det.score,
          );
        }).toList();

        final filtered = applyNMS(unletterboxed, request.iouThreshold);

        replyPort.send(filtered);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Error in InferenceIsolate: $e\n$stackTrace');
        }
        replyPort.send(<Detection>[]);
      }
    });
  }
}
