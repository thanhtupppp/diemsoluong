import 'dart:ui';

class CountingLine {
  final String id;
  final String name;
  final Offset pointA;
  final Offset pointB;

  const CountingLine({
    required this.id,
    required this.name,
    required this.pointA,
    required this.pointB,
  });
}
