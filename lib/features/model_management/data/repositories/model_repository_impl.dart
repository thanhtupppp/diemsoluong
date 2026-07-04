import 'dart:io';
import '../../../../data/models/model_config.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/repositories/model_repository.dart';

class ModelRepositoryImpl implements ModelRepository {
  @override
  Future<List<ModelInfo>> getAvailableModels() async {
    // Default Google AI Edge / MediaPipe object detector bundled with the app.
    return [
      const ModelInfo(
        id: 'efficientdet_lite0_coco',
        name: 'EfficientDet-Lite0 (COCO)',
        backend: 'Google AI Edge / MediaPipe',
        path: ModelConfig.modelAssetPath,
        inputSize: ModelConfig.inputSize,
        labels: ModelConfig.cocoLabels,
      ),
    ];
  }

  @override
  Future<void> downloadModel(ModelInfo model) async {
    // Placeholder cho tải mô hình động từ Cloud
  }

  @override
  Future<bool> validateModelFile(String localPath) async {
    // Kiểm tra tệp tin mô hình cục bộ tồn tại
    final file = File(localPath);
    return file.exists();
  }
}
