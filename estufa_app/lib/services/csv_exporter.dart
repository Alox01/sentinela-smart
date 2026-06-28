import 'csv_exporter_stub.dart'
    if (dart.library.html) 'csv_exporter_web.dart'
    if (dart.library.io) 'csv_exporter_io.dart';

Future<String> exportCsvFile({
  required String fileName,
  required String csvContent,
}) {
  return exportCsvFileImpl(fileName: fileName, csvContent: csvContent);
}
