import '../../../services/isar_service.dart';
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
    await _isar.salvarEstufa(
      nome: nome,
      ip: ip,
      tokenAcesso: tokenAcesso,
      idHardware: idHardware,
    );
  }

  Future<void> atualizar({
    required int id,
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    await _isar.atualizarEstufa(
      id: id,
      nome: nome,
      ip: ip,
      tokenAcesso: tokenAcesso,
      idHardware: idHardware,
    );
  }

  Future<void> remover(int id) async {
    await _isar.removerEstufa(id);
  }
}
