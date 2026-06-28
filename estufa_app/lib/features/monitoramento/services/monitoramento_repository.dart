import '../../../models/ciclo_secagem_entity.dart';
import '../../../models/pending_sync_command_entity.dart';
import '../../../services/isar_service.dart';

class MonitoramentoRepository {
  final IsarService _isar;

  const MonitoramentoRepository(this._isar);

  Future<void> salvarLeitura({
    required String ipEstufa,
    required String nomeEstufa,
    required double temperatura,
    required double umidade,
    required double temperaturaMeta,
    required double umidadeMeta,
    required String aviso,
    required bool alertaIncendio,
  }) async {
    await _isar.salvarLeitura(
      ipEstufa: ipEstufa,
      nomeEstufa: nomeEstufa,
      temperatura: temperatura,
      umidade: umidade,
      temperaturaMeta: temperaturaMeta,
      umidadeMeta: umidadeMeta,
      aviso: aviso,
      alertaIncendio: alertaIncendio,
    );
  }

  Future<CicloSecagemEntity?> buscarCicloAbertoPorIp(String ipEstufa) {
    return _isar.buscarCicloAbertoPorIp(ipEstufa);
  }

  Future<CicloSecagemEntity> iniciarCicloSecagem({
    required String ipEstufa,
    required String nomeEstufa,
  }) {
    return _isar.iniciarCicloSecagem(
      ipEstufa: ipEstufa,
      nomeEstufa: nomeEstufa,
    );
  }

  Future<CicloSecagemEntity?> finalizarCicloSecagem(int cicloId) {
    return _isar.finalizarCicloSecagem(cicloId);
  }

  Future<void> salvarEventoCiclo({
    required String ipEstufa,
    required String nomeEstufa,
    required int cicloId,
    required String tipo,
    required String severidade,
    required String descricao,
    double? valorAnterior,
    double? valorAtual,
  }) {
    return _isar.salvarEventoCiclo(
      ipEstufa: ipEstufa,
      nomeEstufa: nomeEstufa,
      cicloId: cicloId,
      tipo: tipo,
      severidade: severidade,
      descricao: descricao,
      valorAnterior: valorAnterior,
      valorAtual: valorAtual,
    );
  }

  Future<List<PendingSyncCommandEntity>> listarPendenciasPorIp(
    String ipEstufa, {
    int limite = 20,
  }) {
    return _isar.listarPendenciasPorIp(ipEstufa, limite: limite);
  }

  Future<int> contarPendenciasPorIp(String ipEstufa) {
    return _isar.contarPendenciasPorIp(ipEstufa);
  }

  Future<int> limparPendenciasPorIp(String ipEstufa) {
    return _isar.limparPendenciasPorIp(ipEstufa);
  }
}
