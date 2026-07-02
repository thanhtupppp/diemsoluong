import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:diemsoluong/data/models/detection.dart';
import 'package:diemsoluong/domain/usecases/nms_filter.dart';

void main() {
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
