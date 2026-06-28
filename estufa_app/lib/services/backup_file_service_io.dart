import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> salvarBackupJsonImpl({
  required String fileNameBase,
  required String jsonContent,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileNameBase.json');
  await file.writeAsString(jsonContent);
  return file.path;
}
