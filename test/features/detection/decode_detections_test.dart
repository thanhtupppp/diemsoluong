import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:diemsoluong/data/models/model_config.dart';
import 'package:diemsoluong/features/detection/domain/usecases/decode_detections.dart';

void main() {
  group('YOLOv8 Decode Tests', () {
    test('decodeDetections parses flat Float32List correctly', () {
      const numBoxes = 3;
      const numClasses = 1;
      // Kích thước phẳng: (4 + 1) * 3 = 15 phần tử
      // Row 0: x_center -> [0.5, 0.2, 0.9]
      // Row 1: y_center -> [0.5, 0.2, 0.9]
      // Row 2: width    -> [0.1, 0.2, 0.3]
      // Row 3: height   -> [0.1, 0.2, 0.3]
      // Row 4: score_c0 -> [0.8, 0.1, 0.9]
      final output = Float32List.fromList([
        0.5, 0.2, 0.9, // X-centers
        0.5, 0.2, 0.9, // Y-centers
        0.1, 0.2, 0.3, // Widths
        0.1, 0.2, 0.3, // Heights
        0.8, 0.1, 0.9, // Class 0 Scores
      ]);

      final detections = decodeDetections(
        output,
        numBoxes,
        numClasses,
        0.5,
        boxCoordinateFormat: BoxCoordinateFormat.normalized,
      );
      
      // Chỉ 2 box đạt ngưỡng score >= 0.5 (box 0 và box 2)
      expect(detections.length, 2);
      expect(detections[0].classId, 0);
      // Dùng closeTo do float32 precision
      expect(detections[0].score, closeTo(0.8, 1e-5));
      // Kiểm tra toạ độ xCenter = 0.5 * 640 = 320, width = 0.1 * 640 = 64
      // rect left = 320 - 32 = 288
      expect(detections[0].rect.left, closeTo(288.0, 1e-5));
    });

    test('decodeDetections can parse pixel-space box coordinates', () {
      const numBoxes = 1;
      const numClasses = 1;
      final output = Float32List.fromList([
        320, // X-center
        320, // Y-center
        64, // Width
        64, // Height
        0.9, // Class 0 score
      ]);

      final detections = decodeDetections(
        output,
        numBoxes,
        numClasses,
        0.5,
        boxCoordinateFormat: BoxCoordinateFormat.pixels,
      );

      expect(detections, hasLength(1));
      expect(detections.single.rect.left, closeTo(288.0, 1e-5));
      expect(detections.single.rect.top, closeTo(288.0, 1e-5));
      expect(detections.single.rect.right, closeTo(352.0, 1e-5));
      expect(detections.single.rect.bottom, closeTo(352.0, 1e-5));
    });
  });
}
