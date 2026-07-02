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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Detection &&
          runtimeType == other.runtimeType &&
          rect == other.rect &&
          classId == other.classId &&
          score == other.score;

  @override
  int get hashCode => rect.hashCode ^ classId.hashCode ^ score.hashCode;

  @override
  String toString() => 'Detection(rect: $rect, classId: $classId, score: $score)';
}
