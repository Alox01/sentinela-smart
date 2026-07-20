import 'dart:async';

import '../../../models/estufa_entity.dart';
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
