import '../../../models/ciclo_secagem_entity.dart';
import '../../../models/evento_ciclo_entity.dart';
import '../../../models/historico_leitura_entity.dart';
import '../../../services/isar_service.dart';

class RelatorioEstufadaRepository {
  final IsarService _isar;

  const RelatorioEstufadaRepository(this._isar);

  Future<List<CicloSecagemEntity>> listarCiclosPorIp(String ipEstufa) {
    return _isar.listarCiclosPorIp(ipEstufa);
  }

  Future<List<HistoricoLeituraEntity>> listarHistoricoPorIpNoPeriodo(
    String ipEstufa, {
    required DateTime inicio,
    required DateTime fim,
  }) {
    return _isar.listarHistoricoPorIpNoPeriodo(ipEstufa, inicio, fim);
  }

  Future<List<EventoCicloEntity>> listarEventosPorCiclo(int cicloId) {
    return _isar.listarEventosPorCiclo(cicloId);
  }

  Future<void> apagarCiclo(int cicloId) {
    return _isar.apagarCiclo(cicloId);
  }

  Future<void> apagarCiclos(List<int> cicloIds) {
    return _isar.apagarCiclos(cicloIds);
  }
}
