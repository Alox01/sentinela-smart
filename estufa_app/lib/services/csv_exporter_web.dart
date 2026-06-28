// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> exportCsvFileImpl({
  required String fileName,
  required String csvContent,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(csvContent));
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = '$fileName.csv'
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return 'download iniciado no navegador';
}
