import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/estufa_entity.dart';
import '../models/ciclo_secagem_entity.dart';
import '../models/evento_ciclo_entity.dart';
import '../models/historico_leitura_entity.dart';
import '../models/pending_sync_command_entity.dart';

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

class IsarService {
  IsarService._();
  static final IsarService instance = IsarService._();

  static const String _dbName = 'estufa_smart_db';
  static const int _retencaoMesesHistorico = 10;
  static const int _intervaloLimpezaMs = 24 * 60 * 60 * 1000;

  Isar? _isar;
  int _ultimoCleanupMs = 0;

  // Fallback web (quando Isar web não estiver disponível na versão em uso).
  final List<EstufaEntity> _webEstufas = <EstufaEntity>[];
  final List<CicloSecagemEntity> _webCiclos = <CicloSecagemEntity>[];
  final List<EventoCicloEntity> _webEventos = <EventoCicloEntity>[];
  final List<HistoricoLeituraEntity> _webHistorico = <HistoricoLeituraEntity>[];
  final List<PendingSyncCommandEntity> _webPendencias =
      <PendingSyncCommandEntity>[];
  int _webEstufaId = 1;
  int _webCicloId = 1;
  int _webEventoId = 1;
  int _webHistoricoId = 1;
  int _webPendenciaId = 1;

  Future<Isar> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Banco nativo Isar não utilizado no web fallback.',
      );
    }
    if (_isar != null) return _isar!;
    await init();
    return _isar!;
  }

  Future<void> init() async {
    if (kIsWeb) return;
    if (_isar != null) return;

    final existing = Isar.getInstance(_dbName);
    if (existing != null) {
      _isar = existing;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        EstufaEntitySchema,
        CicloSecagemEntitySchema,
        EventoCicloEntitySchema,
        HistoricoLeituraEntitySchema,
        PendingSyncCommandEntitySchema,
      ],
      name: _dbName,
      directory: dir.path,
    );
  }

  Future<List<EstufaEntity>> listarEstufas() async {
    if (kIsWeb) {
      final itens = List<EstufaEntity>.from(_webEstufas);
      itens.sort(
        (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
      );
      return itens;
    }

    final isar = await database;
    final itens = await isar.collection<EstufaEntity>().where().findAll();
    itens.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return itens;
  }

  Future<EstufaEntity> salvarEstufa({
    required String nome,
    required String ip,
    String? tokenAcesso,
  }) async {
    final estufa = EstufaEntity()
      ..chave = '${nome.trim()}::${ip.trim()}'
      ..nome = nome.trim()
      ..ip = ip.trim()
      ..tokenAcesso = _normalizarTextoOpcional(tokenAcesso)
      ..criadaEm = DateTime.now();

    if (kIsWeb) {
      final existenteIndex = _webEstufas.indexWhere(
        (e) => e.chave == estufa.chave,
      );
      if (existenteIndex >= 0) {
        final existente = _webEstufas[existenteIndex];
        estufa.id = existente.id;
        _webEstufas[existenteIndex] = estufa;
      } else {
        estufa.id = _webEstufaId++;
        _webEstufas.add(estufa);
      }
      return estufa;
    }

    final isar = await database;
    await isar.writeTxn(() async {
      await isar.collection<EstufaEntity>().put(estufa);
    });
    return estufa;
  }

  Future<EstufaEntity> atualizarEstufa({
    required int id,
    required String nome,
    required String ip,
    String? tokenAcesso,
  }) async {
    final nomeLimpo = nome.trim();
    final ipLimpo = ip.trim();
    final estufa = EstufaEntity()
      ..id = id
      ..chave = '$nomeLimpo::$ipLimpo'
      ..nome = nomeLimpo
      ..ip = ipLimpo
      ..tokenAcesso = _normalizarTextoOpcional(tokenAcesso)
      ..criadaEm = DateTime.now();

    if (kIsWeb) {
      final index = _webEstufas.indexWhere((e) => e.id == id);
      if (index >= 0) {
        estufa.criadaEm = _webEstufas[index].criadaEm;
        _webEstufas[index] = estufa;
      } else {
        _webEstufas.add(estufa);
      }
      return estufa;
    }

    final isar = await database;
    final existente = await isar.collection<EstufaEntity>().get(id);
    if (existente != null) {
      estufa.criadaEm = existente.criadaEm;
    }

    await isar.writeTxn(() async {
      await isar.collection<EstufaEntity>().put(estufa);
    });
    return estufa;
  }

  Future<void> removerEstufa(int id) async {
    if (kIsWeb) {
      _webEstufas.removeWhere((e) => e.id == id);
      return;
    }

    final isar = await database;
    await isar.writeTxn(() async {
      await isar.collection<EstufaEntity>().delete(id);
    });
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
      ..ipEstufa = ipEstufa
      ..nomeEstufa = nomeEstufa
      ..timestamp = DateTime.now()
      ..temperatura = temperatura
      ..umidade = umidade
      ..temperaturaMeta = temperaturaMeta
      ..umidadeMeta = umidadeMeta
      ..aviso = aviso
      ..alertaIncendio = alertaIncendio;

    if (kIsWeb) {
      leitura.id = _webHistoricoId++;
      _webHistorico.add(leitura);
      _executarLimpezaWebSeNecessario();
      return;
    }

    final isar = await database;
    await isar.writeTxn(() async {
      await isar.collection<HistoricoLeituraEntity>().put(leitura);
    });
    await _executarLimpezaSeNecessario(isar);
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
    final evento = EventoCicloEntity()
      ..ipEstufa = ipEstufa
      ..nomeEstufa = nomeEstufa
      ..cicloId = cicloId
      ..timestamp = DateTime.now()
      ..tipo = tipo
      ..severidade = severidade
      ..descricao = descricao
      ..valorAnterior = valorAnterior
      ..valorAtual = valorAtual;

    if (kIsWeb) {
      evento.id = _webEventoId++;
      _webEventos.add(evento);
      return;
    }

    final isar = await database;
    await isar.writeTxn(() async {
      await isar.collection<EventoCicloEntity>().put(evento);
    });
  }

  Future<List<EventoCicloEntity>> listarEventosPorCiclo(int cicloId) async {
    if (kIsWeb) {
      final itens = _webEventos.where((e) => e.cicloId == cicloId).toList();
      itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return itens;
    }

    final isar = await database;
    final itens = await isar
        .collection<EventoCicloEntity>()
        .filter()
        .cicloIdEqualTo(cicloId)
        .findAll();
    itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return itens;
  }

  Future<CicloSecagemEntity?> buscarCicloAbertoPorIp(String ipEstufa) async {
    if (kIsWeb) {
      final abertos = _webCiclos
          .where((e) => e.ipEstufa == ipEstufa && e.status == 'em_andamento')
          .toList();
      abertos.sort((a, b) => b.inicio.compareTo(a.inicio));
      return abertos.isEmpty ? null : abertos.first;
    }

    final isar = await database;
    final ciclos = await isar
        .collection<CicloSecagemEntity>()
        .filter()
        .ipEstufaEqualTo(ipEstufa)
        .and()
        .statusEqualTo('em_andamento')
        .findAll();
    ciclos.sort((a, b) => b.inicio.compareTo(a.inicio));
    return ciclos.isEmpty ? null : ciclos.first;
  }

  Future<CicloSecagemEntity> iniciarCicloSecagem({
    required String ipEstufa,
    required String nomeEstufa,
  }) async {
    final aberto = await buscarCicloAbertoPorIp(ipEstufa);
    if (aberto != null) return aberto;

    final ciclo = CicloSecagemEntity()
      ..ipEstufa = ipEstufa
      ..nomeEstufa = nomeEstufa
      ..inicio = DateTime.now()
      ..fim = null
      ..status = 'em_andamento'
      ..observacao = '';

    if (kIsWeb) {
      ciclo.id = _webCicloId++;
      _webCiclos.add(ciclo);
      return ciclo;
    }

    final isar = await database;
    await isar.writeTxn(() async {
      await isar.collection<CicloSecagemEntity>().put(ciclo);
    });
    return ciclo;
  }

  Future<CicloSecagemEntity?> finalizarCicloSecagem(int id) async {
    if (kIsWeb) {
      final index = _webCiclos.indexWhere((e) => e.id == id);
      if (index < 0) return null;
      final ciclo = _webCiclos[index]
        ..fim = DateTime.now()
        ..status = 'finalizado';
      _webCiclos[index] = ciclo;
      return ciclo;
    }

    final isar = await database;
    late final CicloSecagemEntity? ciclo;
    await isar.writeTxn(() async {
      ciclo = await isar.collection<CicloSecagemEntity>().get(id);
      if (ciclo == null) return;
      ciclo!
        ..fim = DateTime.now()
        ..status = 'finalizado';
      await isar.collection<CicloSecagemEntity>().put(ciclo!);
    });
    return ciclo;
  }

  Future<List<CicloSecagemEntity>> listarCiclosPorIp(String ipEstufa) async {
    if (kIsWeb) {
      final itens = _webCiclos.where((e) => e.ipEstufa == ipEstufa).toList();
      itens.sort((a, b) => b.inicio.compareTo(a.inicio));
      return itens;
    }

    final isar = await database;
    final itens = await isar
        .collection<CicloSecagemEntity>()
        .filter()
        .ipEstufaEqualTo(ipEstufa)
        .findAll();
    itens.sort((a, b) => b.inicio.compareTo(a.inicio));
    return itens;
  }

  /// Apaga uma estufada por completo: o ciclo, seus eventos e as leituras
  /// gravadas dentro do periodo dele (inicio..fim). Irreversivel.
  Future<void> apagarCiclo(int cicloId) async {
    if (kIsWeb) {
      CicloSecagemEntity? ciclo;
      for (final c in _webCiclos) {
        if (c.id == cicloId) {
          ciclo = c;
          break;
        }
      }
      if (ciclo == null) return;
      final fim = ciclo.fim ?? DateTime.now();
      _webEventos.removeWhere((e) => e.cicloId == cicloId);
      _webHistorico.removeWhere(
        (h) =>
            h.ipEstufa == ciclo!.ipEstufa &&
            !h.timestamp.isBefore(ciclo.inicio) &&
            !h.timestamp.isAfter(fim),
      );
      _webCiclos.removeWhere((c) => c.id == cicloId);
      return;
    }

    final isar = await database;
    final ciclo = await isar.collection<CicloSecagemEntity>().get(cicloId);
    if (ciclo == null) return;
    final fim = ciclo.fim ?? DateTime.now();

    await isar.writeTxn(() async {
      await isar
          .collection<EventoCicloEntity>()
          .filter()
          .cicloIdEqualTo(cicloId)
          .deleteAll();
      await isar
          .collection<HistoricoLeituraEntity>()
          .filter()
          .ipEstufaEqualTo(ciclo.ipEstufa)
          .and()
          .timestampBetween(ciclo.inicio, fim)
          .deleteAll();
      await isar.collection<CicloSecagemEntity>().delete(cicloId);
    });
  }

  /// Apaga varias estufadas em sequencia (limpeza em lote).
  Future<void> apagarCiclos(List<int> cicloIds) async {
    for (final id in cicloIds) {
      await apagarCiclo(id);
    }
  }

  Future<List<HistoricoLeituraEntity>> listarHistoricoPorIp(
    String ipEstufa,
  ) async {
    if (kIsWeb) {
      final itens = _webHistorico.where((e) => e.ipEstufa == ipEstufa).toList();
      itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return itens;
    }

    final isar = await database;
    final itens = await isar
        .collection<HistoricoLeituraEntity>()
        .filter()
        .ipEstufaEqualTo(ipEstufa)
        .findAll();
    itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return itens;
  }

  Future<List<HistoricoLeituraEntity>> listarHistoricoPorIpNoPeriodo(
    String ipEstufa,
    DateTime inicio,
    DateTime fim,
  ) async {
    if (kIsWeb) {
      final itens = _webHistorico
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

    final isar = await database;
    final itens = await isar
        .collection<HistoricoLeituraEntity>()
        .filter()
        .ipEstufaEqualTo(ipEstufa)
        .and()
        .timestampBetween(inicio, fim)
        .findAll();
    itens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return itens;
  }

  Future<void> adicionarComandoPendente({
    required String ipEstufa,
    required Map<String, dynamic> payload,
  }) async {
    final chaveCoalescencia = _chaveCoalescenciaComando(payload);
    final entity = PendingSyncCommandEntity()
      ..ipEstufa = ipEstufa
      ..payloadJson = jsonEncode(payload)
      ..createdAt = DateTime.now();

    if (kIsWeb) {
      if (chaveCoalescencia != null) {
        _webPendencias.removeWhere(
          (e) =>
              e.ipEstufa == ipEstufa &&
              _chaveCoalescenciaPayloadJson(e.payloadJson) == chaveCoalescencia,
        );
      }
      entity.id = _webPendenciaId++;
      _webPendencias.add(entity);
      return;
    }

    final isar = await database;
    await isar.writeTxn(() async {
      if (chaveCoalescencia != null) {
        final existentes = await isar
            .collection<PendingSyncCommandEntity>()
            .filter()
            .ipEstufaEqualTo(ipEstufa)
            .findAll();
        final idsParaRemover = existentes
            .where(
              (e) =>
                  _chaveCoalescenciaPayloadJson(e.payloadJson) ==
                  chaveCoalescencia,
            )
            .map((e) => e.id)
            .toList();
        if (idsParaRemover.isNotEmpty) {
          await isar.collection<PendingSyncCommandEntity>().deleteAll(
            idsParaRemover,
          );
        }
      }
      await isar.collection<PendingSyncCommandEntity>().put(entity);
    });
  }

  Future<List<PendingSyncCommandEntity>> listarPendenciasPorIp(
    String ipEstufa, {
    int limite = 200,
  }) async {
    if (kIsWeb) {
      final itens = _webPendencias
          .where((e) => e.ipEstufa == ipEstufa)
          .toList();
      itens.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (itens.length <= limite) return itens;
      return itens.take(limite).toList();
    }

    final isar = await database;
    final itens = await isar
        .collection<PendingSyncCommandEntity>()
        .filter()
        .ipEstufaEqualTo(ipEstufa)
        .findAll();
    itens.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (itens.length <= limite) return itens;
    return itens.take(limite).toList();
  }

  Future<int> contarPendenciasPorIp(String ipEstufa) async {
    if (kIsWeb) {
      return _webPendencias.where((e) => e.ipEstufa == ipEstufa).length;
    }

    final isar = await database;
    return isar
        .collection<PendingSyncCommandEntity>()
        .filter()
        .ipEstufaEqualTo(ipEstufa)
        .count();
  }

  Future<void> removerPendenciasPorIds(List<int> ids) async {
    if (ids.isEmpty) return;

    if (kIsWeb) {
      _webPendencias.removeWhere((e) => ids.contains(e.id));
      return;
    }

    final isar = await database;
    await isar.writeTxn(() async {
      await isar.collection<PendingSyncCommandEntity>().deleteAll(ids);
    });
  }

  Future<int> limparPendenciasPorIp(String ipEstufa) async {
    if (kIsWeb) {
      final totalAntes = _webPendencias.length;
      _webPendencias.removeWhere((e) => e.ipEstufa == ipEstufa);
      return totalAntes - _webPendencias.length;
    }

    final isar = await database;
    late final int removidas;
    await isar.writeTxn(() async {
      removidas = await isar
          .collection<PendingSyncCommandEntity>()
          .filter()
          .ipEstufaEqualTo(ipEstufa)
          .deleteAll();
    });
    return removidas;
  }

  Future<String> exportarBackupJson() async {
    late final List<EstufaEntity> estufas;
    late final List<CicloSecagemEntity> ciclos;
    late final List<EventoCicloEntity> eventos;
    late final List<HistoricoLeituraEntity> historico;
    late final List<PendingSyncCommandEntity> pendencias;

    if (kIsWeb) {
      estufas = List<EstufaEntity>.from(_webEstufas);
      ciclos = List<CicloSecagemEntity>.from(_webCiclos);
      eventos = List<EventoCicloEntity>.from(_webEventos);
      historico = List<HistoricoLeituraEntity>.from(_webHistorico);
      pendencias = List<PendingSyncCommandEntity>.from(_webPendencias);
    } else {
      final isar = await database;
      estufas = await isar.collection<EstufaEntity>().where().findAll();
      ciclos = await isar.collection<CicloSecagemEntity>().where().findAll();
      eventos = await isar.collection<EventoCicloEntity>().where().findAll();
      historico = await isar
          .collection<HistoricoLeituraEntity>()
          .where()
          .findAll();
      pendencias = await isar
          .collection<PendingSyncCommandEntity>()
          .where()
          .findAll();
    }

    final payload = <String, dynamic>{
      'exportadoEm': DateTime.now().toIso8601String(),
      'retencaoMeses': _retencaoMesesHistorico,
      'estufas': estufas
          .map(
            (e) => <String, dynamic>{
              'id': e.id,
              'chave': e.chave,
              'nome': e.nome,
              'ip': e.ip,
              'tokenAcesso': e.tokenAcesso,
              'criadaEm': e.criadaEm.toIso8601String(),
            },
          )
          .toList(),
      'ciclos': ciclos
          .map(
            (e) => <String, dynamic>{
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
      'eventos': eventos
          .map(
            (e) => <String, dynamic>{
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
      'historico': historico
          .map(
            (e) => <String, dynamic>{
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
      'pendencias': pendencias
          .map(
            (e) => <String, dynamic>{
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

    final estufasRaw = (decoded['estufas'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final historicoRaw = (decoded['historico'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final ciclosRaw = (decoded['ciclos'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final eventosRaw = (decoded['eventos'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final pendenciasRaw = (decoded['pendencias'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final estufas = estufasRaw.map(_mapearEstufa).toList();
    final historico = historicoRaw.map(_mapearHistorico).toList();
    final ciclos = ciclosRaw.map(_mapearCiclo).toList();
    final eventos = eventosRaw.map(_mapearEvento).toList();
    final pendencias = pendenciasRaw.map(_mapearPendencia).toList();

    if (kIsWeb) {
      if (substituirTudo) {
        _webEstufas.clear();
        _webCiclos.clear();
        _webEventos.clear();
        _webHistorico.clear();
        _webPendencias.clear();
      }
      _webEstufas.addAll(estufas);
      _webCiclos.addAll(ciclos);
      _webEventos.addAll(eventos);
      _webHistorico.addAll(historico);
      _webPendencias.addAll(pendencias);
      _recalcularIdsWeb();
      _executarLimpezaWebSeNecessario(force: true);
    } else {
      final isar = await database;
      await isar.writeTxn(() async {
        if (substituirTudo) {
          await isar.collection<EstufaEntity>().clear();
          await isar.collection<CicloSecagemEntity>().clear();
          await isar.collection<EventoCicloEntity>().clear();
          await isar.collection<HistoricoLeituraEntity>().clear();
          await isar.collection<PendingSyncCommandEntity>().clear();
        }

        if (estufas.isNotEmpty) {
          await isar.collection<EstufaEntity>().putAll(estufas);
        }
        if (ciclos.isNotEmpty) {
          await isar.collection<CicloSecagemEntity>().putAll(ciclos);
        }
        if (eventos.isNotEmpty) {
          await isar.collection<EventoCicloEntity>().putAll(eventos);
        }
        if (historico.isNotEmpty) {
          await isar.collection<HistoricoLeituraEntity>().putAll(historico);
        }
        if (pendencias.isNotEmpty) {
          await isar.collection<PendingSyncCommandEntity>().putAll(pendencias);
        }
      });
      await _executarLimpezaSeNecessario(isar, force: true);
    }

    return BackupImportResult(
      estufasImportadas: estufas.length,
      leiturasImportadas: historico.length,
      ciclosImportados: ciclos.length,
      eventosImportados: eventos.length,
      pendenciasImportadas: pendencias.length,
    );
  }

  Future<void> _executarLimpezaSeNecessario(
    Isar isar, {
    bool force = false,
  }) async {
    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && (agoraMs - _ultimoCleanupMs) < _intervaloLimpezaMs) return;

    _ultimoCleanupMs = agoraMs;
    final limite = _subtrairMeses(DateTime.now(), _retencaoMesesHistorico);

    await isar.writeTxn(() async {
      await isar
          .collection<HistoricoLeituraEntity>()
          .filter()
          .timestampLessThan(limite)
          .deleteAll();
    });
  }

  void _executarLimpezaWebSeNecessario({bool force = false}) {
    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && (agoraMs - _ultimoCleanupMs) < _intervaloLimpezaMs) return;

    _ultimoCleanupMs = agoraMs;
    final limite = _subtrairMeses(DateTime.now(), _retencaoMesesHistorico);
    _webHistorico.removeWhere((e) => e.timestamp.isBefore(limite));
  }

  DateTime _subtrairMeses(DateTime data, int meses) {
    final totalMeses = (data.year * 12 + data.month) - meses;
    final novoAno = (totalMeses - 1) ~/ 12;
    final novoMes = ((totalMeses - 1) % 12) + 1;
    final ultimoDiaMes = DateTime(novoAno, novoMes + 1, 0).day;
    final novoDia = data.day > ultimoDiaMes ? ultimoDiaMes : data.day;
    return DateTime(
      novoAno,
      novoMes,
      novoDia,
      data.hour,
      data.minute,
      data.second,
      data.millisecond,
      data.microsecond,
    );
  }

  EstufaEntity _mapearEstufa(Map<String, dynamic> mapa) {
    return EstufaEntity()
      ..id = _parseInt(mapa['id'])
      ..chave = _parseString(mapa['chave'])
      ..nome = _parseString(mapa['nome'])
      ..ip = _parseString(mapa['ip'])
      ..tokenAcesso = _normalizarTextoOpcional(mapa['tokenAcesso']?.toString())
      ..criadaEm = _parseDate(mapa['criadaEm']);
  }

  HistoricoLeituraEntity _mapearHistorico(Map<String, dynamic> mapa) {
    return HistoricoLeituraEntity()
      ..id = _parseInt(mapa['id'])
      ..ipEstufa = _parseString(mapa['ipEstufa'])
      ..nomeEstufa = _parseString(mapa['nomeEstufa'])
      ..timestamp = _parseDate(mapa['timestamp'])
      ..temperatura = _parseDouble(mapa['temperatura'])
      ..umidade = _parseDouble(mapa['umidade'])
      ..temperaturaMeta = _parseDouble(mapa['temperaturaMeta'])
      ..umidadeMeta = _parseDouble(mapa['umidadeMeta'])
      ..aviso = _parseString(mapa['aviso'])
      ..alertaIncendio = _parseBool(mapa['alertaIncendio']);
  }

  EventoCicloEntity _mapearEvento(Map<String, dynamic> mapa) {
    return EventoCicloEntity()
      ..id = _parseInt(mapa['id'])
      ..ipEstufa = _parseString(mapa['ipEstufa'])
      ..nomeEstufa = _parseString(mapa['nomeEstufa'])
      ..cicloId = _parseInt(mapa['cicloId'])
      ..timestamp = _parseDate(mapa['timestamp'])
      ..tipo = _parseString(mapa['tipo'])
      ..severidade = _parseString(mapa['severidade'])
      ..descricao = _parseString(mapa['descricao'])
      ..valorAnterior = mapa['valorAnterior'] == null
          ? null
          : _parseDouble(mapa['valorAnterior'])
      ..valorAtual = mapa['valorAtual'] == null
          ? null
          : _parseDouble(mapa['valorAtual']);
  }

  CicloSecagemEntity _mapearCiclo(Map<String, dynamic> mapa) {
    return CicloSecagemEntity()
      ..id = _parseInt(mapa['id'])
      ..ipEstufa = _parseString(mapa['ipEstufa'])
      ..nomeEstufa = _parseString(mapa['nomeEstufa'])
      ..inicio = _parseDate(mapa['inicio'])
      ..fim = mapa['fim'] == null ? null : _parseDate(mapa['fim'])
      ..status = _parseString(mapa['status']).isEmpty
          ? 'finalizado'
          : _parseString(mapa['status'])
      ..observacao = _parseString(mapa['observacao']);
  }

  PendingSyncCommandEntity _mapearPendencia(Map<String, dynamic> mapa) {
    return PendingSyncCommandEntity()
      ..id = _parseInt(mapa['id'])
      ..ipEstufa = _parseString(mapa['ipEstufa'])
      ..payloadJson = _parseString(mapa['payloadJson'])
      ..createdAt = _parseDate(mapa['createdAt']);
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? Isar.autoIncrement;
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _parseString(dynamic value) {
    return value?.toString() ?? '';
  }

  String? _normalizarTextoOpcional(String? value) {
    final texto = value?.trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  String? _chaveCoalescenciaPayloadJson(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        return _chaveCoalescenciaComando(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _chaveCoalescenciaComando(Map<String, dynamic> payload) {
    if (payload.containsKey('temperaturaMeta')) return 'temperaturaMeta';
    if (payload.containsKey('umidadeMeta')) return 'umidadeMeta';
    if (payload.containsKey('modoSilencioso') ||
        payload['comando'] == 'silenciar') {
      return 'modoSilencioso';
    }
    return null;
  }

  void _recalcularIdsWeb() {
    final maxEstufa = _webEstufas.fold<int>(0, (m, e) => e.id > m ? e.id : m);
    final maxCiclo = _webCiclos.fold<int>(0, (m, e) => e.id > m ? e.id : m);
    final maxEvento = _webEventos.fold<int>(0, (m, e) => e.id > m ? e.id : m);
    final maxHistorico = _webHistorico.fold<int>(
      0,
      (m, e) => e.id > m ? e.id : m,
    );
    final maxPendencias = _webPendencias.fold<int>(
      0,
      (m, e) => e.id > m ? e.id : m,
    );
    _webEstufaId = maxEstufa + 1;
    _webCicloId = maxCiclo + 1;
    _webEventoId = maxEvento + 1;
    _webHistoricoId = maxHistorico + 1;
    _webPendenciaId = maxPendencias + 1;
  }
}
