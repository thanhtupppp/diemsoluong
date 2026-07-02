import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:diemsoluong/data/models/detection.dart';
import 'package:diemsoluong/domain/usecases/decode_yolo_output.dart';
import 'package:diemsoluong/domain/usecases/nms_filter.dart';

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

      final detections = decodeDetections(output, numBoxes, numClasses, 0.5);
      
      // Chỉ 2 box đạt ngưỡng score >= 0.5 (box 0 và box 2)
      expect(detections.length, 2);
      expect(detections[0].classId, 0);
      // Dùng closeTo do float32 precision
      expect(detections[0].score, closeTo(0.8, 1e-5));
      // Kiểm tra toạ độ xCenter = 0.5 * 640 = 320, width = 0.1 * 640 = 64
      // rect left = 320 - 32 = 288
      expect(detections[0].rect.left, closeTo(288.0, 1e-5));
    });
  });

  group('NMS Filter Tests', () {
    test('applyNMS filters overlapping boxes', () {
      final detections = [
        const Detection(rect: Rect.fromLTWH(100, 100, 50, 50), classId: 0, score: 0.9),
        const Detection(rect: Rect.fromLTWH(105, 105, 50, 50), classId: 0, score: 0.8), // Overlapping
        const Detection(rect: Rect.fromLTWH(300, 300, 50, 50), classId: 0, score: 0.85), // Non-overlapping
      ];

      final filtered = applyNMS(detections, 0.45);
      
      expect(filtered.length, 2);
      expect(filtered[0].score, 0.9);
      expect(filtered[1].score, 0.85);
    });
  });
}
