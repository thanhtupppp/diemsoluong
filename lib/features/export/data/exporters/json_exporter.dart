import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/export_job.dart';
import '../../domain/services/exporter.dart';

class JsonExporter implements Exporter {
  @override
  Future<ExportJob> exportData(String fileName, Map<String, dynamic> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName.json';
      final file = File(filePath);

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonString);

      return ExportJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: filePath,
        timestamp: DateTime.now(),
        isSuccess: true,
      );
    } catch (_) {
      return ExportJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: '',
        timestamp: DateTime.now(),
        isSuccess: false,
      );
    }
  }
}
