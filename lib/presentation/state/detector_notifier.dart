import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/detection.dart';
import '../../data/services/tflite_service.dart';

class DetectorState {
  final bool isLoading;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final String? errorMessage;

  DetectorState({
    this.isLoading = false,
    this.imageBytes,
    this.detections = const [],
    this.errorMessage,
  });

  DetectorState copyWith({
    bool? isLoading,
    Uint8List? imageBytes,
    List<Detection>? detections,
    String? errorMessage,
  }) {
    return DetectorState(
      isLoading: isLoading ?? this.isLoading,
      imageBytes: imageBytes ?? this.imageBytes,
      detections: detections ?? this.detections,
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
  @override
  DetectorState build() {
    return DetectorState();
  }

  Future<void> detectImage(Uint8List bytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final tfliteService = ref.read(tfliteServiceProvider);
      final detections = await tfliteService.detectObjects(bytes);
      state = state.copyWith(
        isLoading: false,
        imageBytes: bytes,
        detections: detections,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi nhận diện vật thể: $e',
      );
    }
  }

  void clear() {
    state = DetectorState();
  }
}

final detectorNotifierProvider =
    NotifierProvider.autoDispose<DetectorNotifier, DetectorState>(() {
  return DetectorNotifier();
});
