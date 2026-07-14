import 'dart:convert';

/// Coalescencia da fila offline de comandos.
///
/// Comandos que alteram o mesmo campo compartilham a mesma chave. Quando um
/// comando novo entra na fila, os pendentes com a mesma chave sao removidos —
/// assim o ajuste mais recente vence e um valor antigo nao volta a ser enviado
/// ao aparelho na sincronizacao (o lado do app do Last-Write-Wins).
///
/// Retorna `null` para comandos sem coalescencia (cada um e mantido separado).
String? chaveCoalescenciaComando(Map<String, dynamic> payload) {
  if (payload.containsKey('temperaturaMeta')) return 'temperaturaMeta';
  if (payload.containsKey('umidadeMeta')) return 'umidadeMeta';
  if (payload.containsKey('modoSilencioso') ||
      payload['comando'] == 'silenciar') {
    return 'modoSilencioso';
  }
  return null;
}

/// Igual a [chaveCoalescenciaComando], mas a partir do payload ja serializado
/// (como fica guardado na fila). Retorna `null` se o JSON for invalido ou nao
/// for um objeto.
String? chaveCoalescenciaPayloadJson(String payloadJson) {
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return chaveCoalescenciaComando(decoded);
    }
    return null;
  } catch (_) {
    return null;
  }
}
