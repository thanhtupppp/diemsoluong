import 'package:diemsoluong/features/export/data/exporters/csv_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvExporter', () {
    test('escapeCsvValue quotes comma, quote, and newline values', () {
      expect(CsvExporter.escapeCsvValue('plain'), 'plain');
      expect(CsvExporter.escapeCsvValue('a,b'), '"a,b"');
      expect(CsvExporter.escapeCsvValue('a"b'), '"a""b"');
      expect(CsvExporter.escapeCsvValue('a\nb'), '"a\nb"');
      expect(CsvExporter.escapeCsvValue(null), '');
    });

    test('buildCsvContent escapes keys and values', () {
      final csv = CsvExporter.buildCsvContent({
        'simple': 'value',
        'key,with,comma': 'value,with,comma',
        'quoted': 'say "hello"',
        'multiline': 'line1\nline2',
      });

      expect(csv, contains('Key,Value'));
      expect(csv, contains('simple,value'));
      expect(csv, contains('"key,with,comma","value,with,comma"'));
      expect(csv, contains('quoted,"say ""hello"""'));
      expect(csv, contains('multiline,"line1\nline2"'));
    });
  });
}
