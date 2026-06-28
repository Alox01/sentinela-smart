import 'backup_file_service_stub.dart'
    if (dart.library.html) 'backup_file_service_web.dart'
    if (dart.library.io) 'backup_file_service_io.dart';

Future<String> salvarBackupJson({
  required String fileNameBase,
  required String jsonContent,
}) {
  return salvarBackupJsonImpl(
    fileNameBase: fileNameBase,
    jsonContent: jsonContent,
  );
}
