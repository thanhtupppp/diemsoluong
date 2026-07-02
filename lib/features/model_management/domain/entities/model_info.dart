class ModelInfo {
  final String id;
  final String name;
  final String backend;
  final String path;
  final int inputSize;
  final List<String> labels;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.backend,
    required this.path,
    required this.inputSize,
    required this.labels,
  });
}
