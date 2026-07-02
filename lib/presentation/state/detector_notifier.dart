import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/detection.dart';
import '../../features/counting/data/counters/line_cross_counter.dart';
import '../../features/counting/domain/entities/counting_line.dart';
import '../../features/counting/domain/services/counter.dart';
import '../../features/detection/data/services/tflite_service.dart';
import '../../features/export/data/exporters/csv_exporter.dart';
import '../../features/export/data/exporters/json_exporter.dart';
import '../../features/export/domain/entities/export_job.dart';
import '../../features/export/domain/services/exporter.dart';
import '../../features/model_management/data/repositories/model_repository_impl.dart';
import '../../features/model_management/domain/entities/model_info.dart';
import '../../features/model_management/domain/repositories/model_repository.dart';
import '../../features/tracking/data/trackers/iou_tracker.dart';
import '../../features/tracking/domain/entities/track.dart';
import '../../features/tracking/domain/services/tracker.dart';

class DetectorState {
  final bool isLoading;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final List<Track> tracks;
  final Map<int, int> classCounts;
  final List<ModelInfo> availableModels;
  final ModelInfo? selectedModel;
  final CountingLine countingLine;
  final String? errorMessage;

  const DetectorState({
    this.isLoading = false,
    this.imageBytes,
    this.detections = const [],
    this.tracks = const [],
    this.classCounts = const {},
    this.availableModels = const [],
    this.selectedModel,
    this.countingLine = const CountingLine(
      id: 'central_line',
      name: 'Vạch Đếm Trung Tâm',
      pointA: Offset(0, 320),
      pointB: Offset(640, 320),
    ),
    this.errorMessage,
  });

  DetectorState copyWith({
    bool? isLoading,
    Uint8List? imageBytes,
    List<Detection>? detections,
    List<Track>? tracks,
    Map<int, int>? classCounts,
    List<ModelInfo>? availableModels,
    ModelInfo? selectedModel,
    CountingLine? countingLine,
    String? errorMessage,
  }) {
    return DetectorState(
      isLoading: isLoading ?? this.isLoading,
      imageBytes: imageBytes ?? this.imageBytes,
      detections: detections ?? this.detections,
      tracks: tracks ?? this.tracks,
      classCounts: classCounts ?? this.classCounts,
      availableModels: availableModels ?? this.availableModels,
      selectedModel: selectedModel ?? this.selectedModel,
      countingLine: countingLine ?? this.countingLine,
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

final csvExporterProvider = Provider<Exporter>((ref) => CsvExporter());
final jsonExporterProvider = Provider<Exporter>((ref) => JsonExporter());
final modelRepositoryProvider = Provider<ModelRepository>((ref) => ModelRepositoryImpl());

class DetectorNotifier extends Notifier<DetectorState> {
  final Tracker _tracker = IouTracker();
  late final Counter _counter;
  late final ModelRepository _modelRepository;

  @override
  DetectorState build() {
    const defaultLine = CountingLine(
      id: 'central_line',
      name: 'Vạch Đếm Trung Tâm',
      pointA: Offset(0, 320),
      pointB: Offset(640, 320),
    );
    _counter = LineCrossCounter(line: defaultLine);
    _modelRepository = ref.read(modelRepositoryProvider);
    _initModels();
    return const DetectorState();
  }

  Future<void> _initModels() async {
    final models = await _modelRepository.getAvailableModels();
    if (models.isNotEmpty) {
      state = state.copyWith(
        availableModels: models,
        selectedModel: models.first,
      );
    }
  }

  void updateCountingLine(Offset pointA, Offset pointB) {
    final newLine = CountingLine(
      id: state.countingLine.id,
      name: state.countingLine.name,
      pointA: pointA,
      pointB: pointB,
    );
    _counter = LineCrossCounter(line: newLine);
    state = state.copyWith(countingLine: newLine);
  }

  Future<void> selectModel(ModelInfo model) async {
    state = state.copyWith(selectedModel: model);
    final tfliteService = ref.read(tfliteServiceProvider);
    await tfliteService.initialize(modelPath: model.path);
  }

  Future<void> detectImage(Uint8List bytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final tfliteService = ref.read(tfliteServiceProvider);
      final detections = await tfliteService.detectObjects(
        bytes,
        modelPath: state.selectedModel?.path,
      );
      
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

  Future<ExportJob> exportCurrentData(String format) async {
    final exporter = format == 'csv'
        ? ref.read(csvExporterProvider)
        : ref.read(jsonExporterProvider);

    final exportDataMap = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'selected_model': state.selectedModel?.name ?? 'unknown',
      'total_tracks': state.tracks.length,
      'counted_tracks_total': state.classCounts.values.fold(0, (sum, val) => sum + val),
    };

    // Chi tiết đếm từng lớp nhãn
    state.classCounts.forEach((classId, count) {
      exportDataMap['class_${classId}_count'] = count;
    });

    final fileName = 'detection_report_${DateTime.now().millisecondsSinceEpoch}';
    return exporter.exportData(fileName, exportDataMap);
  }

  void clear() {
    _tracker.reset();
    _counter.reset();
    state = state.copyWith(
      imageBytes: null,
      detections: const [],
      tracks: const [],
      classCounts: const {},
      errorMessage: null,
    );
  }
}

final detectorNotifierProvider =
    NotifierProvider.autoDispose<DetectorNotifier, DetectorState>(() {
  return DetectorNotifier();
});
