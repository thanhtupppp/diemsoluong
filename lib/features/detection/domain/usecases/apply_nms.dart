import 'dart:math';
import 'dart:ui';

import '../../../../data/models/detection.dart';

List<Detection> applyNMS(List<Detection> detections, double iouThreshold) {
  if (detections.isEmpty) return [];

  // Tạo bản sao của list đầu vào để tránh mutate dữ liệu gốc
  final sorted = List<Detection>.from(detections)
    ..sort((a, b) => b.score.compareTo(a.score));

  final selected = <Detection>[];
  final active = List<bool>.filled(sorted.length, true);

  for (int i = 0; i < sorted.length; i++) {
    if (!active[i]) continue;

    final boxA = sorted[i];
    selected.add(boxA);

    for (int j = i + 1; j < sorted.length; j++) {
      if (!active[j]) continue;

      final boxB = sorted[j];
      if (boxA.classId != boxB.classId) continue;

      final iou = calculateIoU(boxA.rect, boxB.rect);
      if (iou >= iouThreshold) {
        active[j] = false;
      }
    }
  }

  return selected;
}

double calculateIoU(Rect rectA, Rect rectB) {
  final intersectionX1 = max(rectA.left, rectB.left);
  final intersectionY1 = max(rectA.top, rectB.top);
  final intersectionX2 = min(rectA.right, rectB.right);
  final intersectionY2 = min(rectA.bottom, rectB.bottom);

  final intersectionWidth = max(0.0, intersectionX2 - intersectionX1);
  final intersectionHeight = max(0.0, intersectionY2 - intersectionY1);
  final intersectionArea = intersectionWidth * intersectionHeight;

  final areaA = rectA.width * rectA.height;
  final areaB = rectB.width * rectB.height;
  final unionArea = areaA + areaB - intersectionArea;

  if (unionArea <= 0.0) return 0.0;
  return intersectionArea / unionArea;
}
