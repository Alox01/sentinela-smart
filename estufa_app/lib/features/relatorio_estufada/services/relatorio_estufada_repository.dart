import '../../../models/ciclo_secagem_entity.dart';
import '../../../models/evento_ciclo_entity.dart';
import '../../../models/historico_leitura_entity.dart';
import '../../../services/isar_service.dart';

/// Tudo o que a tela de relatorios precisa para desenhar a estufada escolhida.
class DadosRelatorioEstufada {
  final List<HistoricoLeituraEntity> leituras;
  final List<CicloSecagemEntity> ciclos;
  final List<EventoCicloEntity> eventos;
  final CicloSecagemEntity? cicloSelecionado;

  const DadosRelatorioEstufada({
    required this.leituras,
    required this.ciclos,
    required this.eventos,
    required this.cicloSelecionado,
  });

  factory DadosRelatorioEstufada.vazio() {
    return const DadosRelatorioEstufada(
      leituras: [],
      ciclos: [],
      eventos: [],
      cicloSelecionado: null,
    );
  }
}

class RelatorioEstufadaRepository {
  final IsarService _isar;

  const RelatorioEstufadaRepository(this._isar);

  /// Relatorio ja pronto, guardado por endereco de estufa.
  ///
  /// Abrir "Relatórios" custava tres consultas ao banco local com a tela ja na
  /// frente do produtor, e ele esperava olhando um giro. As consultas nao
  /// dependem de nada que so exista na tela de relatorios - o monitoramento
  /// tem o mesmo endereco na mao muito antes. Entao ele adianta o trabalho e
  /// aqui fica o resultado.
  static final Map<String, _Precarga> _precargas = {};

  /// Depois disto o produtor pode ter iniciado ou encerrado uma estufada, e um
  /// relatorio velho seria pior do que a espera. Curto de proposito: a precarga
  /// existe para cobrir o toque no menu, nao para virar cache de verdade.
  static const Duration _validadePrecarga = Duration(minutes: 3);

  /// Adianta o relatorio, sem bloquear quem chamou e sem estourar erro: falhar
  /// aqui apenas devolve o comportamento antigo, de carregar na hora.
  void precarregar(String ipEstufa) {
    final atual = _precargas[ipEstufa];
    if (atual != null && !atual.vencida) return;
    final futuro = carregarRelatorio(ipEstufa, guardar: false);
    _precargas[ipEstufa] = _Precarga(futuro, DateTime.now());
    futuro.catchError((_) {
      _precargas.remove(ipEstufa);
      return DadosRelatorioEstufada.vazio();
    });
  }

  /// Consome a precarga daquele endereco, se houver uma valida. Uso unico: a
  /// tela mantem o resultado dela e o "puxar para atualizar" tem de chegar ao
  /// banco de verdade.
  Future<DadosRelatorioEstufada>? consumirPrecarga(String ipEstufa) {
    final guardada = _precargas.remove(ipEstufa);
    if (guardada == null || guardada.vencida) return null;
    return guardada.futuro;
  }

  /// Descarta o que estiver guardado. Chamado quando o proprio app muda os
  /// dados - apagar estufada, por exemplo -, para a proxima abertura nao mostrar
  /// o que acabou de deixar de existir.
  static void esquecerPrecargas() => _precargas.clear();

  Future<DadosRelatorioEstufada> carregarRelatorio(
    String ipEstufa, {
    int? cicloPreferidoId,
    bool guardar = true,
  }) async {
    final ciclos = await listarCiclosPorIp(ipEstufa);
    final ciclo = _escolherCiclo(ciclos, cicloPreferidoId);
    if (ciclo == null) {
      return DadosRelatorioEstufada(
        leituras: const [],
        ciclos: ciclos,
        eventos: const [],
        cicloSelecionado: null,
      );
    }

    final resultados = await Future.wait([
      listarHistoricoPorIpNoPeriodo(
        ipEstufa,
        inicio: ciclo.inicio,
        fim: ciclo.fim ?? DateTime.now(),
      ),
      listarEventosPorCiclo(ciclo.id),
    ]);

    return DadosRelatorioEstufada(
      leituras: resultados[0] as List<HistoricoLeituraEntity>,
      ciclos: ciclos,
      eventos: resultados[1] as List<EventoCicloEntity>,
      cicloSelecionado: ciclo,
    );
  }

  /// A estufada preferida, senao a que esta correndo, senao a mais recente.
  CicloSecagemEntity? _escolherCiclo(
    List<CicloSecagemEntity> ciclos,
    int? preferidoId,
  ) {
    if (ciclos.isEmpty) return null;
    if (preferidoId != null) {
      for (final ciclo in ciclos) {
        if (ciclo.id == preferidoId) return ciclo;
      }
    }
    for (final ciclo in ciclos) {
      if (ciclo.status == 'em_andamento') return ciclo;
    }
    return ciclos.first;
  }

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

  Future<void> apagarCiclo(int cicloId) async {
    await _isar.apagarCiclo(cicloId);
    // O que estava adiantado descreve uma estufada que acabou de deixar de
    // existir. Mostrar isso seria pior do que a espera.
    esquecerPrecargas();
  }

  Future<void> apagarCiclos(List<int> cicloIds) async {
    await _isar.apagarCiclos(cicloIds);
    esquecerPrecargas();
  }
}

class _Precarga {
  final Future<DadosRelatorioEstufada> futuro;
  final DateTime em;

  const _Precarga(this.futuro, this.em);

  bool get vencida =>
      DateTime.now().difference(em) >
      RelatorioEstufadaRepository._validadePrecarga;
}
