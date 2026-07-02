import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/export_job.dart';
import '../../domain/services/exporter.dart';

class CsvExporter implements Exporter {
  @override
  Future<ExportJob> exportData(String fileName, Map<String, dynamic> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName.csv';
      final file = File(filePath);

      final buffer = StringBuffer();
      // Ghi Header
      buffer.writeln('Key,Value');
      // Ghi Rows
      data.forEach((key, value) {
        final escapedValue = value.toString().contains(',')
            ? '"${value.toString().replaceAll('"', '""')}"'
            : value;
        buffer.writeln('$key,$escapedValue');
      });

      await file.writeAsString(buffer.toString());

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
