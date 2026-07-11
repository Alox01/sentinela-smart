/// Decide quando registrar os eventos de "queda" e "retorno" de conexao da
/// estufa. Considera queda apenas quando fica offline por mais de 2 minutos
/// seguidos (evita registrar quedas momentaneas). Logica pura, sem UI.
class RastreadorConexao {
  static const int _tempoQuedaMs = 2 * 60 * 1000;

  int? _offlineDesdeMs;
  bool _quedaRegistrada = false;

  /// Chamar enquanto a estufa esta offline. Retorna true uma unica vez, quando
  /// a queda completa 2 minutos, para o chamador registrar o evento.
  bool avaliarQueda(int nowMs) {
    if (_quedaRegistrada) return false;
    _offlineDesdeMs ??= nowMs;
    if ((nowMs - _offlineDesdeMs!) < _tempoQuedaMs) return false;
    _quedaRegistrada = true;
    return true;
  }

  /// Chamar quando a estufa volta a responder. Reinicia o estado de offline e
  /// retorna true se havia uma queda registrada (para registrar o retorno).
  bool avaliarRetorno() {
    final estavaEmQueda = _quedaRegistrada;
    _offlineDesdeMs = null;
    _quedaRegistrada = false;
    return estavaEmQueda;
  }
}
