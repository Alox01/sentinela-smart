import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> exportCsvFileImpl({
  required String fileName,
  required String csvContent,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName.csv');
  await file.writeAsString(csvContent);
  return file.path;
}
