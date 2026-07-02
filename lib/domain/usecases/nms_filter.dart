import 'dart:math';
import 'dart:ui';
import '../../data/models/detection.dart';

List<Detection> applyNMS(List<Detection> detections, double iouThreshold) {
  if (detections.isEmpty) return [];

  // Sắp xếp giảm dần theo score
  detections.sort((a, b) => b.score.compareTo(a.score));

  final List<Detection> selected = [];
  final List<bool> active = List.filled(detections.length, true);

  for (int i = 0; i < detections.length; i++) {
    if (!active[i]) continue;

    final boxA = detections[i];
    selected.add(boxA);

    for (int j = i + 1; j < detections.length; j++) {
      if (!active[j]) continue;

      final boxB = detections[j];
      if (boxA.classId == boxB.classId) {
        final iou = calculateIoU(boxA.rect, boxB.rect);
        if (iou > iouThreshold) {
          active[j] = false;
        }
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

  final areaA = (rectA.right - rectA.left) * (rectA.bottom - rectA.top);
  final areaB = (rectB.right - rectB.left) * (rectB.bottom - rectB.top);
  final unionArea = areaA + areaB - intersectionArea;

  if (unionArea == 0.0) return 0.0;
  return intersectionArea / unionArea;
}
