import 'dart:math';
import 'dart:ui';

import '../../../../data/models/detection.dart';
import '../../domain/entities/track.dart';
import '../../domain/services/tracker.dart';

class IouTracker implements Tracker {
  final double iouThreshold;
  final double centerDistanceThresholdFactor;
  final double minCenterDistanceThreshold;
  final int maxLostFrames;
  final int maxPathLength;

  List<Track> _activeTracks = [];
  final Map<int, int> _lostFrameCounters = {}; // trackId -> lost frames count
  int _nextTrackId = 1;

  IouTracker({
    this.iouThreshold = 0.3,
    this.centerDistanceThresholdFactor = 1.5,
    this.minCenterDistanceThreshold = 32.0,
    this.maxLostFrames = 5,
    this.maxPathLength = 20,
  });

  @override
  List<Track> update(List<Detection> detections) {
    if (_activeTracks.isEmpty) {
      // Nếu chưa có track nào hoạt động, nạp toàn bộ detections thành track mới
      for (final detection in detections) {
        final center = Offset(
          detection.rect.left + detection.rect.width / 2,
          detection.rect.top + detection.rect.height / 2,
        );
        _activeTracks.add(
          Track(
            id: _nextTrackId++,
            classId: detection.classId,
            rect: detection.rect,
            score: detection.score,
            path: [center],
          ),
        );
      }
      return List<Track>.from(_activeTracks);
    }

    final matchedDetections = List<bool>.filled(detections.length, false);
    final matchedTracks = List<bool>.filled(_activeTracks.length, false);
    final updatedTracks = <Track>[];

    // Match by IoU first, with center-distance fallback for low-FPS jumps.
    for (int i = 0; i < _activeTracks.length; i++) {
      final track = _activeTracks[i];
      double bestMatchScore = -1.0;
      int bestMatchIdx = -1;

      for (int j = 0; j < detections.length; j++) {
        if (matchedDetections[j]) continue;

        final detection = detections[j];
        if (track.classId != detection.classId) continue;

        final iou = _calculateIoU(track.rect, detection.rect);
        final centerDistance = _calculateCenterDistance(
          track.rect,
          detection.rect,
        );
        final centerDistanceThreshold = _calculateCenterDistanceThreshold(
          track.rect,
          detection.rect,
        );

        if (iou < iouThreshold && centerDistance > centerDistanceThreshold) {
          continue;
        }

        final matchScore = iou >= iouThreshold
            ? 1.0 + iou
            : 1.0 - (centerDistance / centerDistanceThreshold);
        if (matchScore > bestMatchScore) {
          bestMatchScore = matchScore;
          bestMatchIdx = j;
        }
      }

      if (bestMatchIdx != -1) {
        // Khớp thành công
        matchedDetections[bestMatchIdx] = true;
        matchedTracks[i] = true;

        final detection = detections[bestMatchIdx];
        final center = Offset(
          detection.rect.left + detection.rect.width / 2,
          detection.rect.top + detection.rect.height / 2,
        );

        final newPath = List<Offset>.from(track.path)..add(center);
        if (newPath.length > maxPathLength) {
          newPath.removeAt(0);
        }

        _lostFrameCounters[track.id] = 0; // Reset lost counter

        updatedTracks.add(
          track.copyWith(
            rect: detection.rect,
            score: detection.score,
            path: newPath,
          ),
        );
      }
    }

    // Xử lý các track hoạt động bị mất dấu (không khớp trong frame này)
    for (int i = 0; i < _activeTracks.length; i++) {
      if (matchedTracks[i]) continue;

      final track = _activeTracks[i];
      final lostFrames = (_lostFrameCounters[track.id] ?? 0) + 1;
      _lostFrameCounters[track.id] = lostFrames;

      if (lostFrames <= maxLostFrames) {
        // Vẫn giữ lại track nhưng không cập nhật toạ độ mới
        updatedTracks.add(track);
      } else {
        // Quá giới hạn khung hình mất dấu, loại bỏ hẳn khỏi registry
        _lostFrameCounters.remove(track.id);
      }
    }

    // Xử lý các detections mới xuất hiện chưa được khớp (New objects)
    for (int j = 0; j < detections.length; j++) {
      if (matchedDetections[j]) continue;

      final detection = detections[j];
      final center = Offset(
        detection.rect.left + detection.rect.width / 2,
        detection.rect.top + detection.rect.height / 2,
      );

      final newTrackId = _nextTrackId++;
      _lostFrameCounters[newTrackId] = 0;

      updatedTracks.add(
        Track(
          id: newTrackId,
          classId: detection.classId,
          rect: detection.rect,
          score: detection.score,
          path: [center],
        ),
      );
    }

    _activeTracks = updatedTracks;
    return List<Track>.from(_activeTracks);
  }

  @override
  void reset() {
    _activeTracks.clear();
    _lostFrameCounters.clear();
    _nextTrackId = 1;
  }

  double _calculateIoU(Rect rectA, Rect rectB) {
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

  double _calculateCenterDistance(Rect rectA, Rect rectB) {
    final centerA = rectA.center;
    final centerB = rectB.center;
    final dx = centerA.dx - centerB.dx;
    final dy = centerA.dy - centerB.dy;
    return sqrt(dx * dx + dy * dy);
  }

  double _calculateCenterDistanceThreshold(Rect rectA, Rect rectB) {
    final maxObjectDimension = max(
      max(rectA.width, rectA.height),
      max(rectB.width, rectB.height),
    );
    return max(
      minCenterDistanceThreshold,
      maxObjectDimension * centerDistanceThresholdFactor,
    );
  }
}
