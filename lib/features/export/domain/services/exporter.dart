import '../entities/export_job.dart';

abstract class Exporter {
  Future<ExportJob> exportData(
    String fileName,
    Map<String, dynamic> data,
  );
}
