import '../../../../data/models/detection.dart';
import '../entities/track.dart';

abstract class Tracker {
  List<Track> update(List<Detection> detections);
  void reset();
}
