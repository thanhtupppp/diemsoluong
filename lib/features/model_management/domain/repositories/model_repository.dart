import '../entities/model_info.dart';

abstract class ModelRepository {
  Future<List<ModelInfo>> getAvailableModels();
  Future<void> downloadModel(ModelInfo model);
  Future<bool> validateModelFile(String localPath);
}
