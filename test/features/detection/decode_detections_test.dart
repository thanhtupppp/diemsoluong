import 'dart:typed_data';

import 'package:diemsoluong/features/detection/domain/usecases/decode_mediapipe_detections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaPipe EfficientDet decode tests', () {
    test('buildEfficientDetAnchors matches Lite0 output anchor count', () {
      final anchors = buildEfficientDetAnchors(inputSize: 320);

      expect(anchors, hasLength(19206));
      expect(anchors.first.xCenter, closeTo(0.0125, 1e-6));
      expect(anchors.first.yCenter, closeTo(0.0125, 1e-6));
    });

    test('buildEfficientDetAnchors scales anchor count with input size', () {
      expect(buildEfficientDetAnchors(inputSize: 256), hasLength(12276));
      expect(buildEfficientDetAnchors(inputSize: 512), hasLength(49104));
    });

    test('decodeMediaPipeDetections decodes raw box offsets', () {
      const inputSize = 320;
      const anchor = EfficientDetAnchor(
        xCenter: 0.5,
        yCenter: 0.5,
        width: 0.25,
        height: 0.25,
      );

      final detections = decodeMediaPipeDetections(
        boxes: Float32List.fromList([
          0.0, // y center offset
          0.0, // x center offset
          0.0, // h log-scale offset
          0.0, // w log-scale offset
        ]),
        scores: Float32List.fromList([0.1, 0.85, 0.2]),
        numBoxes: 1,
        numClasses: 3,
        confidenceThreshold: 0.5,
        anchors: const [anchor],
        inputSize: inputSize,
      );

      expect(detections, hasLength(1));
      expect(detections.single.classId, 1);
      expect(detections.single.score, closeTo(0.85, 1e-6));
      expect(detections.single.rect.left, closeTo(120.0, 1e-6));
      expect(detections.single.rect.top, closeTo(120.0, 1e-6));
      expect(detections.single.rect.right, closeTo(200.0, 1e-6));
      expect(detections.single.rect.bottom, closeTo(200.0, 1e-6));
    });

    test('decodeMediaPipeDetections clamps boxes at image boundaries', () {
      final detections = decodeMediaPipeDetections(
        boxes: Float32List(4),
        scores: Float32List.fromList([0.9]),
        numBoxes: 1,
        numClasses: 1,
        confidenceThreshold: 0.5,
        anchors: const [
          EfficientDetAnchor(
            xCenter: 0.0,
            yCenter: 0.0,
            width: 0.5,
            height: 0.5,
          ),
        ],
        inputSize: 320,
      );

      expect(detections, hasLength(1));
      expect(detections.single.rect.left, 0.0);
      expect(detections.single.rect.top, 0.0);
      expect(detections.single.rect.right, closeTo(80.0, 1e-6));
      expect(detections.single.rect.bottom, closeTo(80.0, 1e-6));
    });

    test('decodeMediaPipeDetections skips degenerate boxes', () {
      final detections = decodeMediaPipeDetections(
        boxes: Float32List(4),
        scores: Float32List.fromList([0.9]),
        numBoxes: 1,
        numClasses: 1,
        confidenceThreshold: 0.5,
        anchors: const [
          EfficientDetAnchor(
            xCenter: 0.0,
            yCenter: 0.5,
            width: 0.0,
            height: 0.5,
          ),
        ],
      );

      expect(detections, isEmpty);
    });

    test('decodeMediaPipeDetections maps boxes with custom input size', () {
      final detections = decodeMediaPipeDetections(
        boxes: Float32List(4),
        scores: Float32List.fromList([0.9]),
        numBoxes: 1,
        numClasses: 1,
        confidenceThreshold: 0.5,
        anchors: const [
          EfficientDetAnchor(
            xCenter: 0.5,
            yCenter: 0.5,
            width: 0.25,
            height: 0.25,
          ),
        ],
        inputSize: 512,
      );

      expect(detections, hasLength(1));
      expect(detections.single.rect.left, closeTo(192.0, 1e-6));
      expect(detections.single.rect.top, closeTo(192.0, 1e-6));
      expect(detections.single.rect.right, closeTo(320.0, 1e-6));
      expect(detections.single.rect.bottom, closeTo(320.0, 1e-6));
    });

    test('decodeMediaPipeDetections filters scores below threshold', () {
      final detections = decodeMediaPipeDetections(
        boxes: Float32List(4),
        scores: Float32List.fromList([0.2, 0.3]),
        numBoxes: 1,
        numClasses: 2,
        confidenceThreshold: 0.5,
        anchors: const [
          EfficientDetAnchor(
            xCenter: 0.5,
            yCenter: 0.5,
            width: 0.25,
            height: 0.25,
          ),
        ],
      );

      expect(detections, isEmpty);
    });

    test('decodeMediaPipeDetections filters to allowed classes early', () {
      final detections = decodeMediaPipeDetections(
        boxes: Float32List(4),
        scores: Float32List.fromList([0.95, 0.7]),
        numBoxes: 1,
        numClasses: 2,
        confidenceThreshold: 0.5,
        anchors: const [
          EfficientDetAnchor(
            xCenter: 0.5,
            yCenter: 0.5,
            width: 0.25,
            height: 0.25,
          ),
        ],
        allowedClassIds: {1},
      );

      expect(detections, hasLength(1));
      expect(detections.single.classId, 1);
      expect(detections.single.score, closeTo(0.7, 1e-6));
    });

    test('decodeMediaPipeDetections supports sigmoid score activation', () {
      final detections = decodeMediaPipeDetections(
        boxes: Float32List(4),
        scores: Float32List.fromList([0.0, 2.0]),
        numBoxes: 1,
        numClasses: 2,
        confidenceThreshold: 0.8,
        anchors: const [
          EfficientDetAnchor(
            xCenter: 0.5,
            yCenter: 0.5,
            width: 0.25,
            height: 0.25,
          ),
        ],
        scoreActivation: ScoreActivation.sigmoid,
      );

      expect(detections, hasLength(1));
      expect(detections.single.classId, 1);
      expect(detections.single.score, closeTo(0.880797, 1e-5));
    });

    test('decodeMediaPipeDetections supports softmax score activation', () {
      final detections = decodeMediaPipeDetections(
        boxes: Float32List(4),
        scores: Float32List.fromList([1.0, 3.0]),
        numBoxes: 1,
        numClasses: 2,
        confidenceThreshold: 0.8,
        anchors: const [
          EfficientDetAnchor(
            xCenter: 0.5,
            yCenter: 0.5,
            width: 0.25,
            height: 0.25,
          ),
        ],
        scoreActivation: ScoreActivation.softmax,
      );

      expect(detections, hasLength(1));
      expect(detections.single.classId, 1);
      expect(detections.single.score, closeTo(0.880797, 1e-5));
    });

    test('decodeMediaPipeDetections logs shape mismatch details', () {
      final messages = <String>[];

      final detections = decodeMediaPipeDetections(
        boxes: Float32List(3),
        scores: Float32List(1),
        numBoxes: 1,
        numClasses: 2,
        confidenceThreshold: 0.5,
        anchors: const [],
        debugLog: messages.add,
      );

      expect(detections, isEmpty);
      expect(messages, hasLength(1));
      expect(messages.single, contains('boxes.length=3'));
      expect(messages.single, contains('scores.length=1'));
      expect(messages.single, contains('anchors.length=0'));
      expect(messages.single, contains('numBoxes=1'));
      expect(messages.single, contains('numClasses=2'));
    });

    test(
      'MediaPipeEfficientDetOutputDecoder delegates to MediaPipe decoder',
      () {
        final decoder = MediaPipeEfficientDetOutputDecoder(
          inputSize: 320,
          anchors: const [
            EfficientDetAnchor(
              xCenter: 0.5,
              yCenter: 0.5,
              width: 0.25,
              height: 0.25,
            ),
          ],
        );

        final detections = decoder.decode(
          boxes: Float32List(4),
          scores: Float32List.fromList([0.9]),
          numBoxes: 1,
          numClasses: 1,
          confidenceThreshold: 0.5,
        );

        expect(detections, hasLength(1));
        expect(detections.single.classId, 0);
      },
    );
  });
}
