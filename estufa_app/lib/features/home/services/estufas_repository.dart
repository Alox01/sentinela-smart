import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/estufa_entity.dart';
import '../../../services/api_service.dart';
import '../../../services/isar_service.dart';
import '../../notificacoes/services/push_notification_service.dart';
import '../models/modelo_estufa.dart';

class EstufasRepository {
  final IsarService _isar;

  const EstufasRepository(this._isar);

  Future<List<ModeloEstufa>> listar() async {
    final entities = await _isar.listarEstufas();
    return entities.map(ModeloEstufa.fromEntity).toList();
  }

  Future<void> salvar({
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    final estufa = await _isar.salvarEstufa(
      nome: nome,
      ip: ip,
      tokenAcesso: tokenAcesso,
      idHardware: idHardware,
    );
    unawaited(PushNotificationService.instance.registrarEstufa(estufa));
    unawaited(_subirChaveParaNuvem(estufa));
  }

  Future<void> atualizar({
    required int id,
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    final estufa = await _isar.atualizarEstufa(
      id: id,
      nome: nome,
      ip: ip,
      tokenAcesso: tokenAcesso,
      idHardware: idHardware,
    );
    unawaited(PushNotificationService.instance.registrarEstufa(estufa));
    unawaited(_subirChaveParaNuvem(estufa));
  }

  /// Leva a chave da estufa para a nuvem, para ela autorizar comandos deste
  /// aparelho sem depender da chave global. Melhor esforco de proposito: quem
  /// esta cadastrando nao pode ver o cadastro falhar por causa disto, e o proprio
  /// aparelho tambem registra a chave dele - os dois caminhos caem no mesmo TOFU.
  Future<void> _subirChaveParaNuvem(EstufaEntity estufa) async {
    final id = estufa.idHardware?.trim();
    final chave = estufa.tokenAcesso?.trim();
    if (id == null || id.isEmpty || chave == null || chave.isEmpty) return;
    final resultado = await ApiService(
      estufa.ip,
      token: chave,
      idHardware: id,
    ).registrarChaveNaNuvem();
    if (resultado == ResultadoChaveNuvem.chaveDivergente) {
      // Sinal de chave velha no app: os comandos remotos vao ser recusados ate
      // ela ser relida no modo de configuracao.
      debugPrint('A nuvem tem outra chave para $id: a chave do app esta velha.');
    }
  }

  Future<void> remover(int id) async {
    final estufas = await _isar.listarEstufas();
    final estufa = estufas.cast<EstufaEntity?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );
    await _isar.removerEstufa(id);
    if (estufa != null) {
      unawaited(PushNotificationService.instance.removerEstufa(estufa));
    }
  }
}
