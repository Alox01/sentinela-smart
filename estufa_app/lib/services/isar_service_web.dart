import 'dart:convert';

import '../models/ciclo_secagem_entity.dart';
import '../models/estufa_entity.dart';
import '../models/evento_ciclo_entity.dart';
import '../models/historico_leitura_entity.dart';
import '../models/pending_sync_command_entity.dart';
import 'coalescencia_comando.dart';

class BackupImportResult {
  final int estufasImportadas;
  final int leiturasImportadas;
  final int ciclosImportados;
  final int eventosImportados;
  final int pendenciasImportadas;

  const BackupImportResult({
    required this.estufasImportadas,
    required this.leiturasImportadas,
    required this.ciclosImportados,
    required this.eventosImportados,
    required this.pendenciasImportadas,
  });
}

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

  Future<String> exportarBackupJson() async {
    final payload = <String, dynamic>{
      'exportadoEm': DateTime.now().toIso8601String(),
      'retencaoMeses': _retencaoMesesHistorico,
      'estufas': _estufas
          .map(
            (e) => {
              'id': e.id,
              'chave': e.chave,
              'nome': e.nome,
              'ip': e.ip,
              'idHardware': e.idHardware,
              'criadaEm': e.criadaEm.toIso8601String(),
            },
          )
          .toList(),
      'ciclos': _ciclos
          .map(
            (e) => {
              'id': e.id,
              'ipEstufa': e.ipEstufa,
              'nomeEstufa': e.nomeEstufa,
              'inicio': e.inicio.toIso8601String(),
              'fim': e.fim?.toIso8601String(),
              'status': e.status,
              'observacao': e.observacao,
            },
          )
          .toList(),
      'eventos': _eventos
          .map(
            (e) => {
              'id': e.id,
              'ipEstufa': e.ipEstufa,
              'nomeEstufa': e.nomeEstufa,
              'cicloId': e.cicloId,
              'timestamp': e.timestamp.toIso8601String(),
              'tipo': e.tipo,
              'severidade': e.severidade,
              'descricao': e.descricao,
              'valorAnterior': e.valorAnterior,
              'valorAtual': e.valorAtual,
            },
          )
          .toList(),
      'historico': _historico
          .map(
            (e) => {
              'id': e.id,
              'ipEstufa': e.ipEstufa,
              'nomeEstufa': e.nomeEstufa,
              'timestamp': e.timestamp.toIso8601String(),
              'temperatura': e.temperatura,
              'umidade': e.umidade,
              'temperaturaMeta': e.temperaturaMeta,
              'umidadeMeta': e.umidadeMeta,
              'aviso': e.aviso,
              'alertaIncendio': e.alertaIncendio,
            },
          )
          .toList(),
      'pendencias': _pendencias
          .map(
            (e) => {
              'id': e.id,
              'ipEstufa': e.ipEstufa,
              'payloadJson': e.payloadJson,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<BackupImportResult> importarBackupJson(
    String jsonContent, {
    bool substituirTudo = true,
  }) async {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Estrutura de backup invalida.');
    }
    final estufas = _mapas(decoded['estufas']).map(_mapearEstufa).toList();
    final historico = _mapas(
      decoded['historico'],
    ).map(_mapearHistorico).toList();
    final ciclos = _mapas(decoded['ciclos']).map(_mapearCiclo).toList();
    final eventos = _mapas(decoded['eventos']).map(_mapearEvento).toList();
    final pendencias = _mapas(
      decoded['pendencias'],
    ).map(_mapearPendencia).toList();
    if (substituirTudo) {
      _estufas.clear();
      _historico.clear();
      _ciclos.clear();
      _eventos.clear();
      _pendencias.clear();
    }
    _estufas.addAll(estufas);
    _historico.addAll(historico);
    _ciclos.addAll(ciclos);
    _eventos.addAll(eventos);
    _pendencias.addAll(pendencias);
    _recalcularIds();
    _limparHistoricoAntigo();
    return BackupImportResult(
      estufasImportadas: estufas.length,
      leiturasImportadas: historico.length,
      ciclosImportados: ciclos.length,
      eventosImportados: eventos.length,
      pendenciasImportadas: pendencias.length,
    );
  }

  List<Map<String, dynamic>> _mapas(dynamic value) =>
      (value as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

  EstufaEntity _mapearEstufa(Map<String, dynamic> m) => EstufaEntity()
    ..id = _inteiro(m['id'])
    ..chave = _texto(m['chave'])
    ..nome = _texto(m['nome'])
    ..ip = _texto(m['ip'])
    ..tokenAcesso = _textoOpcional(m['tokenAcesso']?.toString())
    ..idHardware = _textoOpcional(m['idHardware']?.toString())
    ..criadaEm = _data(m['criadaEm']);

  HistoricoLeituraEntity _mapearHistorico(Map<String, dynamic> m) =>
      HistoricoLeituraEntity()
        ..id = _inteiro(m['id'])
        ..ipEstufa = _texto(m['ipEstufa'])
        ..nomeEstufa = _texto(m['nomeEstufa'])
        ..timestamp = _data(m['timestamp'])
        ..temperatura = _decimal(m['temperatura'])
        ..umidade = _decimal(m['umidade'])
        ..temperaturaMeta = _decimal(m['temperaturaMeta'])
        ..umidadeMeta = _decimal(m['umidadeMeta'])
        ..aviso = _texto(m['aviso'])
        ..alertaIncendio = _booleano(m['alertaIncendio']);

  CicloSecagemEntity _mapearCiclo(Map<String, dynamic> m) {
    final status = _texto(m['status']);
    return CicloSecagemEntity()
      ..id = _inteiro(m['id'])
      ..ipEstufa = _texto(m['ipEstufa'])
      ..nomeEstufa = _texto(m['nomeEstufa'])
      ..inicio = _data(m['inicio'])
      ..fim = m['fim'] == null ? null : _data(m['fim'])
      ..status = status.isEmpty ? 'finalizado' : status
      ..observacao = _texto(m['observacao']);
  }

  EventoCicloEntity _mapearEvento(Map<String, dynamic> m) => EventoCicloEntity()
    ..id = _inteiro(m['id'])
    ..ipEstufa = _texto(m['ipEstufa'])
    ..nomeEstufa = _texto(m['nomeEstufa'])
    ..cicloId = _inteiro(m['cicloId'])
    ..timestamp = _data(m['timestamp'])
    ..tipo = _texto(m['tipo'])
    ..severidade = _texto(m['severidade'])
    ..descricao = _texto(m['descricao'])
    ..valorAnterior = m['valorAnterior'] == null
        ? null
        : _decimal(m['valorAnterior'])
    ..valorAtual = m['valorAtual'] == null ? null : _decimal(m['valorAtual']);

  PendingSyncCommandEntity _mapearPendencia(Map<String, dynamic> m) =>
      PendingSyncCommandEntity()
        ..id = _inteiro(m['id'])
        ..ipEstufa = _texto(m['ipEstufa'])
        ..payloadJson = _texto(m['payloadJson'])
        ..createdAt = _data(m['createdAt']);

  void _limparHistoricoAntigo() {
    final agora = DateTime.now();
    final limite = DateTime(
      agora.year,
      agora.month - _retencaoMesesHistorico,
      agora.day,
    );
    _historico.removeWhere((e) => e.timestamp.isBefore(limite));
  }

  void _recalcularIds() {
    int proximo<T>(Iterable<T> itens, int Function(T) id) =>
        itens.fold<int>(0, (maximo, e) => id(e) > maximo ? id(e) : maximo) + 1;
    _estufaId = proximo(_estufas, (e) => e.id);
    _cicloId = proximo(_ciclos, (e) => e.id);
    _eventoId = proximo(_eventos, (e) => e.id);
    _historicoId = proximo(_historico, (e) => e.id);
    _pendenciaId = proximo(_pendencias, (e) => e.id);
  }

  int _inteiro(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  double _decimal(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _texto(dynamic value) => value?.toString() ?? '';
  String? _textoOpcional(String? value) {
    final texto = value?.trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  bool _booleano(dynamic value) =>
      value == true || '$value'.toLowerCase() == 'true' || '$value' == '1';
  DateTime _data(dynamic value) =>
      DateTime.tryParse('$value') ?? DateTime.now();
}
