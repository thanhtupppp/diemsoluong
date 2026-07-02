import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:diemsoluong/features/counting/data/counters/line_cross_counter.dart';
import 'package:diemsoluong/features/counting/domain/entities/counting_line.dart';
import 'package:diemsoluong/features/tracking/domain/entities/track.dart';

void main() {
  group('LineCrossCounter Tests', () {
    const line = CountingLine(
      id: 'line_1',
      name: 'Vạch Đếm',
      pointA: Offset(0, 100),
      pointB: Offset(200, 100),
    );

    test('counts tracks that intersect the counting line', () {
      final counter = LineCrossCounter(line: line);
      
      // Quỹ đạo di chuyển từ y = 80 đến y = 120 (cắt qua y = 100)
      const track = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 110, 20, 20),
        score: 0.9,
        path: [Offset(50, 80), Offset(50, 120)],
      );

      final result = counter.process([track]);
      expect(result.classCounts[0], equals(1));
      expect(result.countedTrackIds.contains(1), isTrue);
    });

    test('does not count tracks that do not intersect the line', () {
      final counter = LineCrossCounter(line: line);

      // Quỹ đạo di chuyển từ y = 20 đến y = 80 (không cắt qua y = 100)
      const track = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 70, 20, 20),
        score: 0.9,
        path: [Offset(50, 20), Offset(50, 80)],
      );

      final result = counter.process([track]);
      expect(result.classCounts[0], isNull);
      expect(result.countedTrackIds.contains(1), isFalse);
    });

    test('avoids double-counting the same track ID across process updates', () {
      final counter = LineCrossCounter(line: line);

      const trackUpdate1 = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 110, 20, 20),
        score: 0.9,
        path: [Offset(50, 80), Offset(50, 120)],
      );

      final result1 = counter.process([trackUpdate1]);
      expect(result1.classCounts[0], equals(1));

      const trackUpdate2 = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 130, 20, 20),
        score: 0.9,
        path: [Offset(50, 80), Offset(50, 120), Offset(50, 140)],
      );

      final result2 = counter.process([trackUpdate2]);
      expect(result2.classCounts[0], equals(1)); // Vẫn là 1, không tăng thêm
    });
  });
}
