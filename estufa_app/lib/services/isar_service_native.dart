import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/estufa_entity.dart';
import '../models/ciclo_secagem_entity.dart';
import '../models/evento_ciclo_entity.dart';
import '../models/historico_leitura_entity.dart';
import '../models/pending_sync_command_entity.dart';
import 'coalescencia_comando.dart';


class IsarService {
  IsarService._();
  static final IsarService instance = IsarService._();

  static const String _dbName = 'estufa_smart_db';
  static const int _retencaoMesesHistorico = 10;
  static const int _intervaloLimpezaMs = 24 * 60 * 60 * 1000;

  Isar? _isar;
  int _ultimoCleanupMs = 0;

  // Fallback web (quando Isar web nÃ£o estiver disponÃ­vel na versÃ£o em uso).
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
        'Banco nativo Isar nÃ£o utilizado no web fallback.',
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
    String? idHardware,
  }) async {
    final estufa = EstufaEntity()
      ..chave = '${nome.trim()}::${ip.trim()}'
      ..nome = nome.trim()
      ..ip = ip.trim()
      ..tokenAcesso = _normalizarTextoOpcional(tokenAcesso)
      ..idHardware = _normalizarTextoOpcional(idHardware)
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

  // O id capturado automaticamente sobrevive a uma edicao que nao informa outro
  // - o formulario so o envia quando o usuario digita algo. Mas ele foi
  // aprendido DAQUELE endereco, entao trocar o endereco o invalida: o proximo
  // que atender no endereco novo e quem passa a valer. E tambem o conserto de
  // uma estufa que ficou apontada para o aparelho errado.
  static String? _idHerdado(EstufaEntity existente, String ipNovo) =>
      existente.ip == ipNovo ? existente.idHardware : null;

  Future<EstufaEntity> atualizarEstufa({
    required int id,
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    final nomeLimpo = nome.trim();
    final ipLimpo = ip.trim();
    final idHardwareLimpo = _normalizarTextoOpcional(idHardware);
    final estufa = EstufaEntity()
      ..id = id
      ..chave = '$nomeLimpo::$ipLimpo'
      ..nome = nomeLimpo
      ..ip = ipLimpo
      ..tokenAcesso = _normalizarTextoOpcional(tokenAcesso)
      ..idHardware = idHardwareLimpo
      ..criadaEm = DateTime.now();

    if (kIsWeb) {
      final index = _webEstufas.indexWhere((e) => e.id == id);
      if (index >= 0) {
        estufa.criadaEm = _webEstufas[index].criadaEm;
        estufa.idHardware ??= _idHerdado(_webEstufas[index], ipLimpo);
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
      estufa.idHardware ??= _idHerdado(existente, ipLimpo);
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

  // Guarda o idHardware capturado na conexao local, para as leituras remotas
  // puxarem o estado do aparelho certo (status por aparelho na nuvem).
  /// So preenche estufas que ainda NAO tem id. Um endereco pode servir a mais de
  /// uma estufa ao longo do tempo (DHCP, redes diferentes na mesma faixa), entao
  /// sobrescrever pelo endereco repontava uma estufa ja identificada para o
  /// aparelho errado - e ela passava a puxar da nuvem os dados de outra.
  Future<void> definirIdHardwarePorIp(String ip, String idHardware) async {
    if (kIsWeb) {
      for (final e in _webEstufas) {
        if (e.ip == ip && (e.idHardware == null || e.idHardware!.isEmpty)) {
          e.idHardware = idHardware;
        }
      }
      return;
    }
    final isar = await database;
    await isar.writeTxn(() async {
      final estufas = await isar
          .collection<EstufaEntity>()
          .filter()
          .ipEqualTo(ip)
          .findAll();
      for (final e in estufas) {
        if (e.idHardware == null || e.idHardware!.isEmpty) {
          e.idHardware = idHardware;
          await isar.collection<EstufaEntity>().put(e);
        }
      }
    });
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


  String? _normalizarTextoOpcional(String? value) {
    final texto = value?.trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  String? _chaveCoalescenciaPayloadJson(String payloadJson) =>
      chaveCoalescenciaPayloadJson(payloadJson);

  String? _chaveCoalescenciaComando(Map<String, dynamic> payload) =>
      chaveCoalescenciaComando(payload);

}
