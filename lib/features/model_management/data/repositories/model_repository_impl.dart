import 'dart:io';
import '../../../../data/models/model_config.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/repositories/model_repository.dart';

class ModelRepositoryImpl implements ModelRepository {
  @override
  Future<List<ModelInfo>> getAvailableModels() async {
    // Trả về mô hình YOLOv8n mặc định sẵn có trong tài nguyên ứng dụng
    return [
      const ModelInfo(
        id: 'yolov8n_coco',
        name: 'YOLOv8n (COCO)',
        backend: 'TFLite',
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
