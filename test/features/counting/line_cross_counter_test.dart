import 'dart:ui';

import 'package:diemsoluong/features/counting/data/counters/line_cross_counter.dart';
import 'package:diemsoluong/features/counting/domain/entities/counting_line.dart';
import 'package:diemsoluong/features/tracking/domain/entities/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineCrossCounter Tests', () {
    const line = CountingLine(
      id: 'line_1',
      name: 'Counting Line',
      pointA: Offset(0, 0.5),
      pointB: Offset(1, 0.5),
    );
    const imageSize = Size(200, 200);

    test('counts tracks that intersect the counting line', () {
      final counter = LineCrossCounter(line: line);

      const track = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 110, 20, 20),
        score: 0.9,
        path: [Offset(50, 80), Offset(50, 120)],
      );

      final result = counter.process([track], imageSize: imageSize);

      expect(result.classCounts[0], equals(1));
      expect(result.countedTrackIds.contains(1), isTrue);
    });

    test('does not count tracks that do not intersect the line', () {
      final counter = LineCrossCounter(line: line);

      const track = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 70, 20, 20),
        score: 0.9,
        path: [Offset(50, 20), Offset(50, 80)],
      );

      final result = counter.process([track], imageSize: imageSize);

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

      final result1 = counter.process([trackUpdate1], imageSize: imageSize);
      expect(result1.classCounts[0], equals(1));

      const trackUpdate2 = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 130, 20, 20),
        score: 0.9,
        path: [Offset(50, 80), Offset(50, 120), Offset(50, 140)],
      );

      final result2 = counter.process([trackUpdate2], imageSize: imageSize);
      expect(result2.classCounts[0], equals(1));
    });

    test(
      'counts only negative-to-positive movement for positive direction',
      () {
        const directionalLine = CountingLine(
          id: 'line_1',
          name: 'Counting Line',
          pointA: Offset(0, 0.5),
          pointB: Offset(1, 0.5),
          direction: CountingDirection.positive,
        );
        final counter = LineCrossCounter(line: directionalLine);

        const track = Track(
          id: 1,
          classId: 0,
          rect: Rect.fromLTWH(50, 110, 20, 20),
          score: 0.9,
          path: [Offset(50, 80), Offset(50, 120)],
        );

        final result = counter.process([track], imageSize: imageSize);

        expect(result.classCounts[0], equals(1));
      },
    );

    test('ignores opposite movement for positive direction', () {
      const directionalLine = CountingLine(
        id: 'line_1',
        name: 'Counting Line',
        pointA: Offset(0, 0.5),
        pointB: Offset(1, 0.5),
        direction: CountingDirection.positive,
      );
      final counter = LineCrossCounter(line: directionalLine);

      const track = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 80, 20, 20),
        score: 0.9,
        path: [Offset(50, 120), Offset(50, 80)],
      );

      final result = counter.process([track], imageSize: imageSize);

      expect(result.classCounts[0], isNull);
      expect(result.countedTrackIds, isEmpty);
    });

    test('counts positive-to-negative movement for negative direction', () {
      const directionalLine = CountingLine(
        id: 'line_1',
        name: 'Counting Line',
        pointA: Offset(0, 0.5),
        pointB: Offset(1, 0.5),
        direction: CountingDirection.negative,
      );
      final counter = LineCrossCounter(line: directionalLine);

      const track = Track(
        id: 1,
        classId: 0,
        rect: Rect.fromLTWH(50, 80, 20, 20),
        score: 0.9,
        path: [Offset(50, 120), Offset(50, 80)],
      );

      final result = counter.process([track], imageSize: imageSize);

      expect(result.classCounts[0], equals(1));
    });
  });
}
