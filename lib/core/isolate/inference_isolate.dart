import 'dart:isolate';
import 'dart:typed_data';
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
  late Isolate _isolate;
  late SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> init() async {
    final token = RootIsolateToken.instance!;
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      [_receivePort.sendPort, token],
    );

    _sendPort = await _receivePort.first as SendPort;
    _isReady = true;
  }

  Future<List<Detection>> runInference(InferenceRequest request) async {
    final responsePort = ReceivePort();
    _sendPort.send([request, responsePort.sendPort]);
    final result = await responsePort.first as List<Detection>;
    return result;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.beforeNextEvent);
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

    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    commandPort.listen((message) async {
      final request = message[0] as InferenceRequest;
      final replyPort = message[1] as SendPort;

      try {
        // 1. Tiền xử lý ảnh sang Float32List [1, 640, 640, 3]
        final inputBuffer = ImageService.preprocessImage(
          request.imageBytes,
          ModelConfig.inputSize,
        );

        if (inputBuffer.isEmpty) {
          replyPort.send(<Detection>[]);
          return;
        }

        // YOLOv8n có 1 output tensor hình dạng [1, 4 + num_classes, 8400]
        final numClasses = interpreter.getOutputTensors().first.shape[1] - 4;
        final numBoxes = interpreter.getOutputTensors().first.shape[2];
        final outputBuffer = Float32List(1 * (4 + numClasses) * numBoxes);

        // 2. Chạy mô hình
        interpreter.run(
          inputBuffer.reshape([1, ModelConfig.inputSize, ModelConfig.inputSize, 3]),
          outputBuffer.reshape([1, 4 + numClasses, numBoxes]),
        );

        // 3. Giải mã và NMS
        final decoded = decodeDetections(
          outputBuffer,
          numBoxes,
          numClasses,
          request.confidenceThreshold,
        );
        final filtered = applyNMS(decoded, request.iouThreshold);

        replyPort.send(filtered);
      } catch (e) {
        replyPort.send(<Detection>[]);
      }
    });
  }
}
