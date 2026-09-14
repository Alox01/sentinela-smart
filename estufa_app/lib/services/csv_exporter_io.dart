import 'dart:io';

import 'package:path_provider/path_provider.dart';

// Na pasta temporaria: o arquivo existe so para ser compartilhado. Ate
// 14/09/2026 ele ia para a pasta de documentos do app, que no Android nenhum
// gerenciador de arquivos mostra - o produtor exportava e nao achava o CSV.
Future<String> exportCsvFileImpl({
  required String fileName,
  required String csvContent,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName.csv');
  await file.writeAsString(csvContent);
  return file.path;
}
