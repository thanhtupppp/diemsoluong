import 'dart:ui';

class Detection {
  final Rect rect;
  final int classId;
  final double score;

  const Detection({
    required this.rect,
    required this.classId,
    required this.score,
  });

  @override
  String toString() => 'Detection(rect: $rect, classId: $classId, score: $score)';
}
