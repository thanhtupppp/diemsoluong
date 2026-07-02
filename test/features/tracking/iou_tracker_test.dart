import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:diemsoluong/data/models/detection.dart';
import 'package:diemsoluong/features/tracking/data/trackers/iou_tracker.dart';

void main() {
  group('IouTracker Tests', () {
    test('update creates new tracks for initial detections', () {
      final tracker = IouTracker();
      final detections = [
        const Detection(rect: Rect.fromLTWH(10, 10, 50, 50), score: 0.9, classId: 0),
        const Detection(rect: Rect.fromLTWH(100, 100, 40, 40), score: 0.8, classId: 1),
      ];

      final tracks = tracker.update(detections);
      expect(tracks.length, equals(2));
      expect(tracks[0].id, equals(1));
      expect(tracks[0].classId, equals(0));
      expect(tracks[1].id, equals(2));
      expect(tracks[1].classId, equals(1));
    });

    test('update matches detections across frames with same track ID', () {
      final tracker = IouTracker(iouThreshold: 0.3);
      final frame1 = [
        const Detection(rect: Rect.fromLTWH(10, 10, 50, 50), score: 0.9, classId: 0),
      ];

      final tracks1 = tracker.update(frame1);
      expect(tracks1[0].id, equals(1));

      // Đối tượng di chuyển nhẹ sang bên phải (IoU lớn)
      final frame2 = [
        const Detection(rect: Rect.fromLTWH(12, 10, 50, 50), score: 0.95, classId: 0),
      ];

      final tracks2 = tracker.update(frame2);
      expect(tracks2.length, equals(1));
      expect(tracks2[0].id, equals(1)); // Vẫn là ID 1
      expect(tracks2[0].path.length, equals(2)); // Lịch sử đường đi dài ra
    });

    test('update disposes lost tracks after maxLostFrames limit', () {
      final tracker = IouTracker(maxLostFrames: 2);
      final frame1 = [
        const Detection(rect: Rect.fromLTWH(10, 10, 50, 50), score: 0.9, classId: 0),
      ];

      tracker.update(frame1);

      // 1 frame không phát hiện thấy đối tượng nào
      tracker.update([]);

      // Vẫn giữ lại track nhưng ở chế độ mất dấu tạm thời
      expect(tracker.update([]).isEmpty, isFalse);

      // Frame tiếp theo không thấy nữa -> Vết bám bị xoá bỏ
      expect(tracker.update([]).isEmpty, isTrue);
    });
  });
}
