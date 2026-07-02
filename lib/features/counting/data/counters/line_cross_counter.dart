import 'dart:ui';

import '../../../tracking/domain/entities/track.dart';
import '../../domain/entities/counting_line.dart';
import '../../domain/entities/counting_result.dart';
import '../../domain/services/counter.dart';

class LineCrossCounter implements Counter {
  static const double _epsilon = 1e-9;

  final CountingLine line;

  final Map<int, int> _classCounts = {};
  final Set<int> _countedIds = {};

  LineCrossCounter({required this.line});

  @override
  CountingResult process(List<Track> tracks, {Size? imageSize}) {
    final resolvedImageSize = imageSize ?? const Size(1, 1);
    final linePointA = line.pointAInImage(resolvedImageSize);
    final linePointB = line.pointBInImage(resolvedImageSize);

    for (final track in tracks) {
      if (_countedIds.contains(track.id)) continue;
      if (track.path.length < 2) continue;

      // Lấy 2 vị trí tâm gần nhất của đối tượng để lập phân đoạn di chuyển
      final pPrev = track.path[track.path.length - 2];
      final pLast = track.path[track.path.length - 1];

      if (_crossesLine(linePointA, linePointB, pPrev, pLast)) {
        _countedIds.add(track.id);
        _classCounts[track.classId] = (_classCounts[track.classId] ?? 0) + 1;
      }
    }

    return CountingResult(
      classCounts: Map<int, int>.from(_classCounts),
      countedTrackIds: Set<int>.from(_countedIds),
    );
  }

  @override
  void reset() {
    _classCounts.clear();
    _countedIds.clear();
  }

  bool _crossesLine(Offset a, Offset b, Offset previous, Offset current) {
    final previousSide = _signedDistanceFromLine(a, b, previous);
    final currentSide = _signedDistanceFromLine(a, b, current);
    final previousSign = _sideSign(previousSide);
    final currentSign = _sideSign(currentSide);

    if (previousSign == 0 && currentSign == 0) return false;

    final changedSide =
        previousSign == 0 || currentSign == 0 || previousSign != currentSign;
    if (!changedSide) return false;

    final movementIntersectsSegment = _segmentsIntersect(
      a,
      b,
      previous,
      current,
    );
    if (!movementIntersectsSegment) return false;

    switch (line.direction) {
      case CountingDirection.any:
        return true;
      case CountingDirection.positive:
        return previousSign < 0 && currentSign >= 0;
      case CountingDirection.negative:
        return previousSign > 0 && currentSign <= 0;
    }
  }

  double _signedDistanceFromLine(Offset a, Offset b, Offset point) {
    return (b.dx - a.dx) * (point.dy - a.dy) -
        (b.dy - a.dy) * (point.dx - a.dx);
  }

  bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);

    if (o1 != o2 && o3 != o4) return true;

    if (o1 == 0 && _isOnSegment(a, c, b)) return true;
    if (o2 == 0 && _isOnSegment(a, d, b)) return true;
    if (o3 == 0 && _isOnSegment(c, a, d)) return true;
    if (o4 == 0 && _isOnSegment(c, b, d)) return true;

    return false;
  }

  int _orientation(Offset p, Offset q, Offset r) {
    final value = _signedDistanceFromLine(p, q, r);
    final sign = _sideSign(value);
    if (sign == 0) return 0;
    return sign > 0 ? 1 : 2;
  }

  int _sideSign(double value) {
    if (value.abs() <= _epsilon) return 0;
    return value > 0 ? 1 : -1;
  }

  bool _isOnSegment(Offset p, Offset q, Offset r) {
    return q.dx <= _max(p.dx, r.dx) + _epsilon &&
        q.dx + _epsilon >= _min(p.dx, r.dx) &&
        q.dy <= _max(p.dy, r.dy) + _epsilon &&
        q.dy + _epsilon >= _min(p.dy, r.dy);
  }

  double _min(double a, double b) => a < b ? a : b;

  double _max(double a, double b) => a > b ? a : b;
}
