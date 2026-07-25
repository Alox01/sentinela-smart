import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preferencias_notificacao.dart';

/// Guarda as preferencias de notificacao (global) e avisa quem escuta quando
/// mudam. Fonte unica: a tela de preferencias edita, o resto do app le daqui
/// para respeitar os interruptores mesmo com o app aberto (e, mais tarde, para
/// o servidor de push saber o que suprimir).
class PreferenciasNotificacaoService extends ChangeNotifier {
  static const String _chave = 'preferencias_notificacao_v1';

  static final PreferenciasNotificacaoService instance =
      PreferenciasNotificacaoService._();

  PreferenciasNotificacaoService._();

  PreferenciasNotificacao _preferencias = PreferenciasNotificacao.padrao();
  bool _carregado = false;

  PreferenciasNotificacao get preferencias => _preferencias;
  bool get carregado => _carregado;

  Future<void> carregar() async {
    if (_carregado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferencias = PreferenciasNotificacao.fromJsonString(
        prefs.getString(_chave),
      );
    } catch (_) {
      _preferencias = PreferenciasNotificacao.padrao();
    }
    _carregado = true;
    notifyListeners();
  }

  Future<void> atualizar(PreferenciasNotificacao novas) async {
    _preferencias = novas;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, novas.toJsonString());
    } catch (_) {
      // Persistir e melhor esforco: a UI ja refletiu a mudanca em memoria.
    }
  }
}
