import 'csv_exporter_io.dart';

/// Grava o CSV do relatorio e devolve o caminho.
///
/// Ate 04/08/2026 isto era um export condicional com tres implementacoes
/// (`_io`, `_web`, `_stub`), porque o app tambem rodava no navegador. Com a web
/// fora, sobrou a de arquivo - a unica que alguem ja executou.
Future<String> exportCsvFile({
  required String fileName,
  required String csvContent,
}) {
  return exportCsvFileImpl(fileName: fileName, csvContent: csvContent);
}
