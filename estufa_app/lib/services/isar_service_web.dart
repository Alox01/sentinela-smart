import 'dart:convert';

import '../models/ciclo_secagem_entity.dart';
import '../models/estufa_entity.dart';
import '../models/evento_ciclo_entity.dart';
import '../models/historico_leitura_entity.dart';
import '../models/pending_sync_command_entity.dart';
import 'coalescencia_comando.dart';


/// Armazenamento leve usado apenas pela versao Web.
///
/// O APK continua usando Isar. No navegador, o estado e mantido durante a
/// sessao; o historico oficial permanece no PostgreSQL do servidor.
class IsarService {
  IsarService._();
  static final IsarService instance = IsarService._();

  static const int _retencaoMesesHistorico = 10;

  final List<EstufaEntity> _estufas = [];
  final List<CicloSecagemEntity> _ciclos = [];
  final List<EventoCicloEntity> _eventos = [];
  final List<HistoricoLeituraEntity> _historico = [];
  final List<PendingSyncCommandEntity> _pendencias = [];

  int _estufaId = 1;
  int _cicloId = 1;
  int _eventoId = 1;
  int _historicoId = 1;
  int _pendenciaId = 1;

  Future<void> init() async {}

  Future<List<EstufaEntity>> listarEstufas() async {
    final itens = List<EstufaEntity>.from(_estufas);
    itens.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return itens;
  }

  Future<EstufaEntity> salvarEstufa({
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    final nomeLimpo = nome.trim();
    final ipLimpo = ip.trim();
    final estufa = EstufaEntity()
      ..chave = '$nomeLimpo::$ipLimpo'
      ..nome = nomeLimpo
      ..ip = ipLimpo
      ..tokenAcesso = _textoOpcional(tokenAcesso)
      ..idHardware = _textoOpcional(idHardware)
      ..criadaEm = DateTime.now();
    final index = _estufas.indexWhere((e) => e.chave == estufa.chave);
    if (index >= 0) {
      estufa.id = _estufas[index].id;
      estufa.criadaEm = _estufas[index].criadaEm;
      _estufas[index] = estufa;
    } else {
      estufa.id = _estufaId++;
      _estufas.add(estufa);
    }
    return estufa;
  }

  Future<EstufaEntity> atualizarEstufa({
    required int id,
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    final nomeLimpo = nome.trim();
    final ipLimpo = ip.trim();
    final estufa = EstufaEntity()
      ..id = id
      ..chave = '$nomeLimpo::$ipLimpo'
      ..nome = nomeLimpo
      ..ip = ipLimpo
      ..tokenAcesso = _textoOpcional(tokenAcesso)
      ..idHardware = _textoOpcional(idHardware)
      ..criadaEm = DateTime.now();
    final index = _estufas.indexWhere((e) => e.id == id);
    if (index >= 0) {
      estufa.criadaEm = _estufas[index].criadaEm;
      estufa.idHardware ??= _estufas[index].idHardware;
      _estufas[index] = estufa;
    } else {
      _estufas.add(estufa);
      if (id >= _estufaId) _estufaId = id + 1;
    }
    return estufa;
  }

  Future<void> removerEstufa(int id) async {
    _estufas.removeWhere((e) => e.id == id);
  }

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
    final leitura = HistoricoLeituraEntity()
      ..id = _historicoId++
      ..ipEstufa = ipEstufa
      ..nomeEstufa = nomeEstufa
      ..timestamp = DateTime.now()
      ..temperatura = temperatura
      ..umidade = umidade
      ..temperaturaMeta = temperaturaMeta
      ..umidadeMeta = umidadeMeta
      ..aviso = aviso
      ..alertaIncendio = alertaIncendio;
    _historico.add(leitura);
    _limparHistoricoAntigo();
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
  }) async {
    _eventos.add(
      EventoCicloEntity()
        ..id = _eventoId++
        ..ipEstufa = ipEstufa
        ..nomeEstufa = nomeEstufa
        ..cicloId = cicloId
        ..timestamp = DateTime.now()
        ..tipo = tipo
        ..severidade = severidade
        ..descricao = descricao
        ..valorAnterior = valorAnterior
        ..valorAtual = valorAtual,
    );
  }

  Future<List<EventoCicloEntity>> listarEventosPorCiclo(int cicloId) async {
    final itens = _eventos.where((e) => e.cicloId == cicloId).toList();
    itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return itens;
  }

  Future<CicloSecagemEntity?> buscarCicloAbertoPorIp(String ipEstufa) async {
    final itens = _ciclos
        .where((e) => e.ipEstufa == ipEstufa && e.status == 'em_andamento')
        .toList();
    itens.sort((a, b) => b.inicio.compareTo(a.inicio));
    return itens.isEmpty ? null : itens.first;
  }

  Future<CicloSecagemEntity> iniciarCicloSecagem({
    required String ipEstufa,
    required String nomeEstufa,
  }) async {
    final aberto = await buscarCicloAbertoPorIp(ipEstufa);
    if (aberto != null) return aberto;
    final ciclo = CicloSecagemEntity()
      ..id = _cicloId++
      ..ipEstufa = ipEstufa
      ..nomeEstufa = nomeEstufa
      ..inicio = DateTime.now()
      ..fim = null
      ..status = 'em_andamento'
      ..observacao = '';
    _ciclos.add(ciclo);
    return ciclo;
  }

  Future<CicloSecagemEntity?> finalizarCicloSecagem(int id) async {
    final index = _ciclos.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final ciclo = _ciclos[index]
      ..fim = DateTime.now()
      ..status = 'finalizado';
    return ciclo;
  }

  Future<List<CicloSecagemEntity>> listarCiclosPorIp(String ipEstufa) async {
    final itens = _ciclos.where((e) => e.ipEstufa == ipEstufa).toList();
    itens.sort((a, b) => b.inicio.compareTo(a.inicio));
    return itens;
  }

  Future<void> apagarCiclo(int cicloId) async {
    final index = _ciclos.indexWhere((e) => e.id == cicloId);
    if (index < 0) return;
    final ciclo = _ciclos[index];
    final fim = ciclo.fim ?? DateTime.now();
    _eventos.removeWhere((e) => e.cicloId == cicloId);
    _historico.removeWhere(
      (h) =>
          h.ipEstufa == ciclo.ipEstufa &&
          !h.timestamp.isBefore(ciclo.inicio) &&
          !h.timestamp.isAfter(fim),
    );
    _ciclos.removeAt(index);
  }

  Future<void> apagarCiclos(List<int> cicloIds) async {
    for (final id in cicloIds) {
      await apagarCiclo(id);
    }
  }

  Future<List<HistoricoLeituraEntity>> listarHistoricoPorIp(
    String ipEstufa,
  ) async {
    final itens = _historico.where((e) => e.ipEstufa == ipEstufa).toList();
    itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return itens;
  }

  Future<List<HistoricoLeituraEntity>> listarHistoricoPorIpNoPeriodo(
    String ipEstufa,
    DateTime inicio,
    DateTime fim,
  ) async {
    final itens = _historico
        .where(
          (e) =>
              e.ipEstufa == ipEstufa &&
              !e.timestamp.isBefore(inicio) &&
              !e.timestamp.isAfter(fim),
        )
        .toList();
    itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return itens;
  }

  /// So preenche estufas que ainda NAO tem id. Um endereco pode servir a mais de
  /// uma estufa ao longo do tempo (DHCP, redes diferentes na mesma faixa), entao
  /// sobrescrever pelo endereco repontava uma estufa ja identificada para o
  /// aparelho errado - e ela passava a puxar da nuvem os dados de outra.
  Future<void> definirIdHardwarePorIp(String ip, String idHardware) async {
    for (final estufa in _estufas) {
      if (estufa.ip == ip &&
          (estufa.idHardware == null || estufa.idHardware!.isEmpty)) {
        estufa.idHardware = idHardware;
      }
    }
  }

  Future<void> adicionarComandoPendente({
    required String ipEstufa,
    required Map<String, dynamic> payload,
  }) async {
    final chave = chaveCoalescenciaComando(payload);
    if (chave != null) {
      _pendencias.removeWhere(
        (e) =>
            e.ipEstufa == ipEstufa &&
            chaveCoalescenciaPayloadJson(e.payloadJson) == chave,
      );
    }
    _pendencias.add(
      PendingSyncCommandEntity()
        ..id = _pendenciaId++
        ..ipEstufa = ipEstufa
        ..payloadJson = jsonEncode(payload)
        ..createdAt = DateTime.now(),
    );
  }

  Future<List<PendingSyncCommandEntity>> listarPendenciasPorIp(
    String ipEstufa, {
    int limite = 200,
  }) async {
    final itens = _pendencias.where((e) => e.ipEstufa == ipEstufa).toList();
    itens.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return itens.length <= limite ? itens : itens.take(limite).toList();
  }

  Future<int> contarPendenciasPorIp(String ipEstufa) async =>
      _pendencias.where((e) => e.ipEstufa == ipEstufa).length;

  Future<void> removerPendenciasPorIds(List<int> ids) async {
    _pendencias.removeWhere((e) => ids.contains(e.id));
  }

  Future<int> limparPendenciasPorIp(String ipEstufa) async {
    final antes = _pendencias.length;
    _pendencias.removeWhere((e) => e.ipEstufa == ipEstufa);
    return antes - _pendencias.length;
  }


  void _limparHistoricoAntigo() {
    final agora = DateTime.now();
    final limite = DateTime(
      agora.year,
      agora.month - _retencaoMesesHistorico,
      agora.day,
    );
    _historico.removeWhere((e) => e.timestamp.isBefore(limite));
  }

  String? _textoOpcional(String? value) {
    final texto = value?.trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

}
