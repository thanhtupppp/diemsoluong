import 'dart:async';
import 'dart:io';
import 'dart:isolate';
// ignore: unnecessary_import
import 'dart:typed_data';
// ignore: unnecessary_import
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../data/models/detection.dart';
import '../../domain/usecases/apply_nms.dart';
import '../../domain/usecases/decode_mediapipe_detections.dart';
import '../services/image_service.dart';

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
  ReceivePort? _receivePort;
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> init(String modelPath) async {
    if (_isReady) return;

    final token = RootIsolateToken.instance!;
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    try {
      final isolate = await Isolate.spawn(_isolateEntryPoint, [
        receivePort.sendPort,
        token,
        modelPath,
      ]);
      _isolate = isolate;

      _sendPort = await receivePort.first as SendPort;
      _isReady = true;
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  Future<List<Detection>> runInference(InferenceRequest request) async {
    if (!_isReady || _sendPort == null) {
      throw StateError('InferenceIsolate is not ready.');
    }
    final responsePort = ReceivePort();
    try {
      _sendPort!.send([request, responsePort.sendPort]);
      final result =
          await responsePort.first.timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('Inference request timed out.'),
              )
              as List<Detection>;
      return result;
    } finally {
      responsePort.close();
    }
  }

  void dispose() {
    _isReady = false;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _receivePort = null;
  }

  @pragma('vm:entry-point')
  static void _isolateEntryPoint(List<dynamic> args) async {
    final mainSendPort = args[0] as SendPort;
    final token = args[1] as RootIsolateToken;
    final modelPath = args[2] as String;

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    // Khởi tạo interpreter tflite trong Isolate phụ
    final options = InterpreterOptions()..threads = 4;
    options.useNnApiForAndroid = true;

    final Interpreter interpreter;
    if (modelPath.startsWith('assets/')) {
      interpreter = await Interpreter.fromAsset(modelPath, options: options);
    } else {
      interpreter = Interpreter.fromFile(File(modelPath), options: options);
    }

    final inputShape = interpreter.getInputTensors().first.shape;
    final inputSize = inputShape[1]; // e.g. 320 for EfficientDet-Lite0
    final outputTensors = interpreter.getOutputTensors();
    final outputSpecs = _buildOutputSpecs(outputTensors);
    final boxesSpec = outputSpecs.firstWhere(
      (spec) => spec.isBoxTensor,
      orElse: () => throw StateError('MediaPipe box output tensor not found.'),
    );
    final scoresSpec = outputSpecs.firstWhere(
      (spec) => spec.isScoreTensor,
      orElse: () =>
          throw StateError('MediaPipe score output tensor not found.'),
    );
    final numBoxes = boxesSpec.shape[1];
    final numClasses = scoresSpec.shape[2];
    final outputDecoder = MediaPipeEfficientDetOutputDecoder(
      inputSize: inputSize,
    );

    if (outputDecoder.anchors.length != numBoxes) {
      throw StateError(
        'EfficientDet anchor count ${outputDecoder.anchors.length} does not match model output $numBoxes.',
      );
    }

    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    commandPort.listen((message) async {
      final request = message[0] as InferenceRequest;
      final replyPort = message[1] as SendPort;

      try {
        // 1. Tiền xử lý ảnh sang PreprocessResult
        final preprocessResult = ImageService.preprocessImage(
          request.imageBytes,
          inputSize,
        );

        if (preprocessResult == null) {
          replyPort.send(<Detection>[]);
          return;
        }

        final outputBuffers = _createOutputBuffers(outputSpecs);

        // 2. Run the Google AI Edge / MediaPipe EfficientDet model.
        interpreter.runForMultipleInputs([
          preprocessResult.input.reshape(inputShape),
        ], outputBuffers.map);

        // 3. Decode raw boxes/scores with EfficientDet anchors.
        final decoded = outputDecoder.decode(
          boxes: outputBuffers.byPosition[boxesSpec.position]!,
          scores: outputBuffers.byPosition[scoresSpec.position]!,
          numBoxes: numBoxes,
          numClasses: numClasses,
          confidenceThreshold: request.confidenceThreshold,
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

  static List<_OutputSpec> _buildOutputSpecs(List<Tensor> tensors) {
    return [
      for (int i = 0; i < tensors.length; i++)
        _OutputSpec(position: i, shape: tensors[i].shape),
    ];
  }

  static _OutputBuffers _createOutputBuffers(List<_OutputSpec> specs) {
    final outputMap = <int, Object>{};
    final byPosition = <int, Float32List>{};

    for (final spec in specs) {
      final buffer = Float32List(spec.elementCount);
      byPosition[spec.position] = buffer;
      outputMap[spec.position] = buffer.reshape(spec.shape);
    }

    return _OutputBuffers(map: outputMap, byPosition: byPosition);
  }
}

class _OutputSpec {
  final int position;
  final List<int> shape;

  const _OutputSpec({required this.position, required this.shape});

  int get elementCount => shape.fold(1, (value, element) => value * element);

  bool get isBoxTensor => shape.length == 3 && shape[2] == 4;

  bool get isScoreTensor => shape.length == 3 && shape[2] > 4;
}

class _OutputBuffers {
  final Map<int, Object> map;
  final Map<int, Float32List> byPosition;

  const _OutputBuffers({required this.map, required this.byPosition});
}
