final RegExp _idLegado = RegExp(r'^ESP32_([0-9A-F]{6})$');
final RegExp _idCompleto = RegExp(r'^ESP32_([0-9A-F]{12})$');

/// Reconhece somente a ampliacao introduzida quando o identificador deixou de
/// usar os ultimos 24 bits e passou a usar o MAC inteiro do ESP32.
///
/// Qualquer outra troca continua sendo outro aparelho. A relacao e direcional:
/// cadastro antigo de 6 hex -> resposta nova de 12 hex.
bool ehMigracaoDeIdLegado(String? idAtual, String? idNovo) {
  final atual = idAtual?.trim().toUpperCase() ?? '';
  final novo = idNovo?.trim().toUpperCase() ?? '';
  final legado = _idLegado.firstMatch(atual);
  final completo = _idCompleto.firstMatch(novo);
  if (legado == null || completo == null) return false;
  return completo.group(1)!.endsWith(legado.group(1)!);
}

bool idsDoMesmoAparelho(String? esperado, String? recebido) {
  final a = esperado?.trim().toUpperCase() ?? '';
  final b = recebido?.trim().toUpperCase() ?? '';
  return a == b || ehMigracaoDeIdLegado(a, b);
}
