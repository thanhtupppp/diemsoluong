import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/detection.dart';
import '../../features/counting/data/counters/line_cross_counter.dart';
import '../../features/counting/domain/entities/counting_line.dart';
import '../../features/counting/domain/services/counter.dart';
import '../../features/detection/data/services/tflite_service.dart';
import '../../features/tracking/data/trackers/iou_tracker.dart';
import '../../features/tracking/domain/entities/track.dart';
import '../../features/tracking/domain/services/tracker.dart';

class DetectorState {
  final bool isLoading;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final List<Track> tracks;
  final Map<int, int> classCounts;
  final String? errorMessage;

  const DetectorState({
    this.isLoading = false,
    this.imageBytes,
    this.detections = const [],
    this.tracks = const [],
    this.classCounts = const {},
    this.errorMessage,
  });

  DetectorState copyWith({
    bool? isLoading,
    Uint8List? imageBytes,
    List<Detection>? detections,
    List<Track>? tracks,
    Map<int, int>? classCounts,
    String? errorMessage,
  }) {
    return DetectorState(
      isLoading: isLoading ?? this.isLoading,
      imageBytes: imageBytes ?? this.imageBytes,
      detections: detections ?? this.detections,
      tracks: tracks ?? this.tracks,
      classCounts: classCounts ?? this.classCounts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Định nghĩa Riverpod Provider mới theo Riverpod 3.x
final tfliteServiceProvider = Provider<TfliteService>((ref) {
  final service = TfliteService();
  ref.onDispose(() => service.dispose());
  return service;
});

class DetectorNotifier extends Notifier<DetectorState> {
  final Tracker _tracker = IouTracker();
  late final Counter _counter;

  final CountingLine countingLine = const CountingLine(
    id: 'central_line',
    name: 'Vạch Đếm Trung Tâm',
    pointA: Offset(0, 320),
    pointB: Offset(640, 320),
  );

  @override
  DetectorState build() {
    _counter = LineCrossCounter(line: countingLine);
    return const DetectorState();
  }

  Future<void> detectImage(Uint8List bytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final tfliteService = ref.read(tfliteServiceProvider);
      final detections = await tfliteService.detectObjects(bytes);
      
      final tracks = _tracker.update(detections);
      final countResult = _counter.process(tracks);

      state = state.copyWith(
        isLoading: false,
        imageBytes: bytes,
        detections: detections,
        tracks: tracks,
        classCounts: countResult.classCounts,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi nhận diện vật thể: $e',
      );
    }
  }

  void clear() {
    _tracker.reset();
    _counter.reset();
    state = const DetectorState();
  }
}

final detectorNotifierProvider =
    NotifierProvider.autoDispose<DetectorNotifier, DetectorState>(() {
  return DetectorNotifier();
});
