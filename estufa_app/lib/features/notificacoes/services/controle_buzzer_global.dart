import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../../services/isar_service.dart';

/// Estado global do buzzer de temperatura: um unico interruptor que vale para
/// TODAS as estufas do produtor. Nao faz sentido calar o buzzer de uma estufa e
/// deixar as outras apitando; para desligar so uma, o produtor segura o botao do
/// buzzer no proprio aparelho (o firmware resolve o conflito por aparelho via
/// LWW no `buzzerTimestamp`).
///
/// O fogo nunca e afetado: o firmware toca a sirene de incendio mesmo com o
/// buzzer de temperatura desligado.
class ControleBuzzerGlobal extends ChangeNotifier {
  static const String _chave = 'buzzer_global_ativo_v1';

  static final ControleBuzzerGlobal instance = ControleBuzzerGlobal._();
  ControleBuzzerGlobal._();

  bool _ativo = true;
  bool _carregado = false;

  bool get ativo => _ativo;
  bool get carregado => _carregado;

  Future<void> carregar() async {
    if (_carregado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _ativo = prefs.getBool(_chave) ?? true;
    } catch (_) {
      _ativo = true;
    }
    _carregado = true;
    notifyListeners();
  }

  /// Persiste a intencao e envia o comando para todas as estufas. A intencao
  /// vale mesmo se nenhuma estiver alcancavel agora: as offline recebem o
  /// comando quando reconectarem (fila de pendencias + LWW). Devolve se o
  /// comando alcancou ao menos uma estufa na hora.
  Future<bool> definir(bool ativo) async {
    _ativo = ativo;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chave, ativo);
    } catch (_) {
      // Persistir e melhor esforco: a UI ja refletiu a mudanca em memoria.
    }

    final agora = DateTime.now().millisecondsSinceEpoch;
    var alcancouAlguma = false;
    try {
      final estufas = await IsarService.instance.listarEstufas();
      for (final estufa in estufas) {
        final api = ApiService(
          estufa.ip,
          token: estufa.tokenAcesso,
          idHardware: estufa.idHardware,
        );
        final ok = await api.enviarSincronizacao({
          'buzzerAtivo': ativo,
          'buzzerTimestamp': agora,
        });
        if (ok) alcancouAlguma = true;
      }
    } catch (_) {
      // Sem estufas ou falha ao listar: a intencao ja ficou salva.
    }
    return alcancouAlguma;
  }
}
