class ExportJob {
  final String id;
  final String filePath;
  final DateTime timestamp;
  final bool isSuccess;

  const ExportJob({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.isSuccess,
  });
}
