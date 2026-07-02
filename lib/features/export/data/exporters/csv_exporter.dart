import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/export_job.dart';
import '../../domain/services/exporter.dart';

class CsvExporter implements Exporter {
  static String buildCsvContent(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('Key,Value');
    data.forEach((key, value) {
      buffer.writeln('${escapeCsvValue(key)},${escapeCsvValue(value)}');
    });
    return buffer.toString();
  }

  static String escapeCsvValue(Object? value) {
    final rawValue = value?.toString() ?? '';
    final mustQuote =
        rawValue.contains(',') ||
        rawValue.contains('"') ||
        rawValue.contains('\n') ||
        rawValue.contains('\r');

    if (!mustQuote) return rawValue;

    final escaped = rawValue.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Future<ExportJob> exportData(
    String fileName,
    Map<String, dynamic> data,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName.csv';
      final file = File(filePath);

      await file.writeAsString(buildCsvContent(data));

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
