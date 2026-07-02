import 'dart:ui';

enum CountingDirection { any, positive, negative }

class CountingLine {
  final String id;
  final String name;
  final Offset pointA;
  final Offset pointB;
  final CountingDirection direction;

  const CountingLine({
    required this.id,
    required this.name,
    required this.pointA,
    required this.pointB,
    this.direction = CountingDirection.any,
  });

  Offset pointAInImage(Size imageSize) => toImagePoint(pointA, imageSize);

  Offset pointBInImage(Size imageSize) => toImagePoint(pointB, imageSize);

  static Offset toImagePoint(Offset normalizedPoint, Size imageSize) {
    return Offset(
      normalizedPoint.dx * imageSize.width,
      normalizedPoint.dy * imageSize.height,
    );
  }

  static Offset toNormalizedPoint(Offset imagePoint, Size imageSize) {
    if (imageSize.isEmpty) return Offset.zero;
    return Offset(
      (imagePoint.dx / imageSize.width).clamp(0.0, 1.0),
      (imagePoint.dy / imageSize.height).clamp(0.0, 1.0),
    );
  }

  CountingLine copyWith({
    String? id,
    String? name,
    Offset? pointA,
    Offset? pointB,
    CountingDirection? direction,
  }) {
    return CountingLine(
      id: id ?? this.id,
      name: name ?? this.name,
      pointA: pointA ?? this.pointA,
      pointB: pointB ?? this.pointB,
      direction: direction ?? this.direction,
    );
  }
}
