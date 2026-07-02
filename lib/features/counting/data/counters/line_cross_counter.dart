import 'dart:ui';

import '../../../tracking/domain/entities/track.dart';
import '../../domain/entities/counting_line.dart';
import '../../domain/entities/counting_result.dart';
import '../../domain/services/counter.dart';

class LineCrossCounter implements Counter {
  final CountingLine line;

  final Map<int, int> _classCounts = {};
  final Set<int> _countedIds = {};

  LineCrossCounter({required this.line});

  @override
  CountingResult process(List<Track> tracks) {
    for (final track in tracks) {
      if (_countedIds.contains(track.id)) continue;
      if (track.path.length < 2) continue;

      // Lấy 2 vị trí tâm gần nhất của đối tượng để lập phân đoạn di chuyển
      final pPrev = track.path[track.path.length - 2];
      final pLast = track.path[track.path.length - 1];

      if (_checkIntersection(line.pointA, line.pointB, pPrev, pLast)) {
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

  /// Tính hướng xoay của bộ ba điểm (P, Q, R)
  /// Trả về: 0 (Collinear), 1 (Clockwise), 2 (Counter-Clockwise)
  int _orientation(Offset p, Offset q, Offset r) {
    final val = (q.dy - p.dy) * (r.dx - q.dx) - (q.dx - p.dx) * (r.dy - q.dy);
    if (val == 0.0) return 0;
    return val > 0.0 ? 1 : 2;
  }

  /// Kiểm tra xem hai đoạn thẳng AB và CD có giao nhau hay không
  bool _checkIntersection(Offset a, Offset b, Offset c, Offset d) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);

    // General case: khác hướng xoay chéo nhau
    if (o1 != o2 && o3 != o4) {
      return true;
    }

    // Các trường hợp trùng hợp đặc biệt (collinear segments) không bắt buộc cho đếm thông thường
    return false;
  }
}
