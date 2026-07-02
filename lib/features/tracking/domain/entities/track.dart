import 'dart:ui';

class Track {
  final int id;
  final int classId;
  final Rect rect;
  final double score;
  final List<Offset> path;

  const Track({
    required this.id,
    required this.classId,
    required this.rect,
    required this.score,
    required this.path,
  });

  Track copyWith({
    int? id,
    int? classId,
    Rect? rect,
    double? score,
    List<Offset>? path,
  }) {
    return Track(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      rect: rect ?? this.rect,
      score: score ?? this.score,
      path: path ?? this.path,
    );
  }
}
