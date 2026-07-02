import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:diemsoluong/data/models/detection.dart';
import 'package:diemsoluong/features/detection/data/isolates/inference_isolate.dart';
import 'package:diemsoluong/features/detection/data/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInferenceIsolate extends InferenceIsolate {
  FakeInferenceIsolate({
    this.runError,
    this.result = const [],
  });

  final Object? runError;
  final List<Detection> result;

  bool _ready = false;
  int disposeCount = 0;
  final initializedModelPaths = <String>[];
  final requests = <InferenceRequest>[];

  @override
  bool get isReady => _ready;

  @override
  Future<void> init(String modelPath) async {
    initializedModelPaths.add(modelPath);
    _ready = true;
  }

  @override
  Future<List<Detection>> runInference(InferenceRequest request) async {
    requests.add(request);
    final error = runError;
    if (error != null) {
      throw error;
    }
    return result;
  }

  @override
  void dispose() {
    disposeCount += 1;
    _ready = false;
  }
}

void main() {
  group('TfliteService isolate lifecycle', () {
    test('replaces isolate after inference failure so next request can recover',
        () async {
      var createCount = 0;
      final created = <FakeInferenceIsolate>[];

      final service = TfliteService(
        isolateFactory: () {
          final isolate = createCount == 0
              ? FakeInferenceIsolate(
                  runError: TimeoutException('simulated timeout'),
                )
              : FakeInferenceIsolate(
                  result: const [
                    Detection(
                      rect: Rect.fromLTWH(10, 20, 30, 40),
                      classId: 1,
                      score: 0.9,
                    ),
                  ],
                );
          createCount += 1;
          created.add(isolate);
          return isolate;
        },
      );

      await expectLater(
        service.detectObjects(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<TimeoutException>()),
      );

      expect(created, hasLength(2));
      expect(created.first.disposeCount, 1);

      final detections = await service.detectObjects(Uint8List.fromList([4, 5]));

      expect(detections, hasLength(1));
      expect(detections.single.classId, 1);
      expect(created[1].initializedModelPaths, hasLength(1));
      expect(created[1].requests, hasLength(1));
    });

    test('replaces ready isolate before loading a different model', () async {
      final created = <FakeInferenceIsolate>[];

      final service = TfliteService(
        isolateFactory: () {
          final isolate = FakeInferenceIsolate();
          created.add(isolate);
          return isolate;
        },
      );

      await service.initialize(modelPath: 'assets/models/first.tflite');
      await service.initialize(modelPath: 'assets/models/second.tflite');

      expect(created, hasLength(2));
      expect(created.first.disposeCount, 1);
      expect(created.first.initializedModelPaths, ['assets/models/first.tflite']);
      expect(created[1].initializedModelPaths, ['assets/models/second.tflite']);
    });
  });
}
