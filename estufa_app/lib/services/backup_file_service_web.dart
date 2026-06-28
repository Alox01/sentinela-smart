// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> salvarBackupJsonImpl({
  required String fileNameBase,
  required String jsonContent,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(jsonContent));
  final blob = html.Blob([bytes], 'application/json;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = '$fileNameBase.json'
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return 'download iniciado no navegador';
}
