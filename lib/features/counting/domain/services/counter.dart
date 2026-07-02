import '../../../tracking/domain/entities/track.dart';
import '../entities/counting_result.dart';

abstract class Counter {
  CountingResult process(List<Track> tracks);
  void reset();
}
