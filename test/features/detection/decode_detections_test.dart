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
  });
}
