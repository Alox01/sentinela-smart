import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../services/isar_service.dart';
import '../../notificacoes/models/preferencias_notificacao.dart';
import '../../notificacoes/services/preferencias_notificacao_service.dart';
import '../models/agendamento_ajuste.dart';

/// Agendamento de ajuste, com o trabalho dividido entre celular e nuvem porque
/// nenhum dos dois resolve sozinho:
///
/// - **o aviso** e um alarme local no proprio celular. Funciona sem internet
///   nenhuma, que e o caso comum na propriedade;
/// - **a troca do ajuste** e registrada no servidor. O Android dispara a
///   notificacao na hora, mas nao roda codigo do app para enviar o comando — e o
///   cenario e justamente o produtor longe, com o app fechado.
///
/// Por isso o servidor **nao** manda push: se mandasse, o mesmo evento chegaria
/// duas vezes. Ele so troca o ajuste, em silencio.
class AgendamentoService extends ChangeNotifier {
  static const String _chave = 'agendamentos_ajuste_v1';
  static const String _cloudApiUrl = String.fromEnvironment('CLOUD_API_URL');

  /// Canal proprio: e um lembrete que o produtor pediu, nao um alerta de
  /// problema. Misturar com o canal de alertas faria o aviso de "erguer o calor"
  /// herdar som e importancia de emergencia.
  static const AndroidNotificationChannel canal = AndroidNotificationChannel(
    'sentinela_agendamentos',
    'Ajustes agendados',
    description: 'Lembretes de ajuste marcados pelo produtor.',
    importance: Importance.high,
  );

  /// Mesmo lembrete, mas tocando como alarme — para quem liga "Tocar" no evento
  /// "Ajuste agendado". Nasce desligado: alarme e para problema, e um lembrete
  /// que o proprio produtor marcou nao e problema. Quem precisa ser acordado as
  /// 3h para por lenha liga o interruptor.
  static const AndroidNotificationChannel canalComAlarme =
      AndroidNotificationChannel(
        'sentinela_agendamentos_alarme_v1',
        'Ajustes agendados (alarme)',
        description:
            'Lembretes de ajuste que tocam como alarme, em volume alto.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarme_estufa'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      );

  static OpcaoEvento get _preferencia => PreferenciasNotificacaoService
      .instance
      .preferencias
      .opcao(EventoNotificacao.ajusteAgendado);

  static final AgendamentoService instance = AgendamentoService._();
  AgendamentoService._();

  final FlutterLocalNotificationsPlugin _notificacoes =
      FlutterLocalNotificationsPlugin();

  List<AgendamentoAjuste> _agendamentos = const [];
  bool _carregado = false;
  bool _fusoPronto = false;

  List<AgendamentoAjuste> get agendamentos => _agendamentos;
  bool get carregado => _carregado;

  bool get _suportado =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Carrega o que estava salvo e **reagenda tudo**. Reiniciar o celular apaga
  /// os alarmes do sistema; o receptor de boot do plugin cobre o caso normal, mas
  /// nem todo fabricante entrega o BOOT_COMPLETED, entao reagendar ao abrir e a
  /// rede de seguranca.
  Future<void> carregar() async {
    if (_carregado) return;
    _carregado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _agendamentos = AgendamentoAjuste.listaDeJson(prefs.getString(_chave));
    } catch (_) {
      _agendamentos = const [];
    }

    // Passou da hora enquanto o app estava fechado: nao ha o que reagendar, e o
    // aviso ja foi dado (ou perdido) pelo sistema.
    final agora = DateTime.now();
    final futuros = _agendamentos
        .where((a) => a.quando.isAfter(agora))
        .toList();
    // Venceu sem nunca ter sido registrado na nuvem: o ajuste NAO foi aplicado e
    // nao sera - tarde demais para valer. Sair da lista em silencio deixaria o
    // produtor achando que aconteceu, entao ele e avisado antes de o item sumir.
    final perdidos = _agendamentos
        .where((a) => !a.quando.isAfter(agora) && !a.registradoNaNuvem)
        .toList();
    if (futuros.length != _agendamentos.length) {
      _agendamentos = futuros;
      await _persistir();
    }
    for (final perdido in perdidos) {
      await _avisarNaoAplicado(perdido);
    }

    for (final agendamento in _agendamentos) {
      await _agendarAvisoLocal(agendamento);
    }
    notifyListeners();
    unawaited(reenviarPendentes());
  }

  /// Tenta de novo registrar na nuvem o que foi agendado sem internet.
  ///
  /// Agendar sem sinal e o caso comum na propriedade, nao a excecao. Sem esta
  /// segunda tentativa, o agendamento criado offline ficaria para sempre so como
  /// aviso, mesmo com o celular voltando a ter internet minutos depois.
  ///
  /// A chave nao viaja junto do agendamento salvo — e segredo, e nao tem por que
  /// ficar duplicada no disco. Vem da estufa cadastrada na hora de reenviar.
  Future<void> reenviarPendentes() async {
    final agora = DateTime.now();
    final pendentes = _agendamentos
        .where(
          (a) =>
              !a.registradoNaNuvem &&
              a.idHardware != null &&
              a.quando.isAfter(agora),
        )
        .toList();
    if (pendentes.isEmpty) return;

    Map<int, String?> tokenPorEstufa;
    try {
      final estufas = await IsarService.instance.listarEstufas();
      tokenPorEstufa = {
        for (final estufa in estufas) estufa.id: estufa.tokenAcesso,
      };
    } catch (_) {
      return;
    }

    var mudou = false;
    for (final pendente in pendentes) {
      final id = await _registrarNaNuvem(
        pendente,
        tokenPorEstufa[pendente.idEstufa],
      );
      if (id == null) continue;
      _agendamentos = [
        for (final a in _agendamentos)
          a.idLocal == pendente.idLocal ? a.comId(id) : a,
      ];
      mudou = true;
    }

    if (mudou) {
      await _persistir();
      notifyListeners();
    }
  }

  /// Cria o agendamento: alarme local primeiro (o que sempre funciona), registro
  /// na nuvem depois. Devolve o agendamento criado — `registradoNaNuvem` diz se o
  /// ajuste vai mudar sozinho ou se o produtor tera de aplicar na mao.
  Future<AgendamentoAjuste> criar({
    required int idEstufa,
    required String nomeEstufa,
    required String? idHardware,
    required String? tokenAcesso,
    required DateTime quando,
    double? temperaturaMeta,
    double? temperaturaDelta,
    double? umidadeMeta,
    double? umidadeDelta,
  }) async {
    await carregar();

    final agendamento = AgendamentoAjuste(
      idLocal: _proximoIdLocal(),
      idEstufa: idEstufa,
      nomeEstufa: nomeEstufa,
      idHardware: idHardware,
      quando: quando,
      temperaturaMeta: temperaturaMeta,
      temperaturaDelta: temperaturaDelta,
      umidadeMeta: umidadeMeta,
      umidadeDelta: umidadeDelta,
    );

    await _agendarAvisoLocal(agendamento);
    final id = await _registrarNaNuvem(agendamento, tokenAcesso);

    _agendamentos = [..._agendamentos, agendamento.comId(id)]
      ..sort((a, b) => a.quando.compareTo(b.quando));
    await _persistir();
    notifyListeners();
    return _agendamentos.firstWhere((a) => a.idLocal == agendamento.idLocal);
  }

  Future<void> cancelar(
    AgendamentoAjuste agendamento, {
    String? tokenAcesso,
  }) async {
    await _notificacoes.cancel(id: agendamento.idLocal);
    if (agendamento.id != null && agendamento.idHardware != null) {
      await _removerDaNuvem(agendamento, tokenAcesso);
    }
    _agendamentos = _agendamentos
        .where((a) => a.idLocal != agendamento.idLocal)
        .toList();
    await _persistir();
    notifyListeners();
  }

  List<AgendamentoAjuste> daEstufa(int idEstufa) =>
      _agendamentos.where((a) => a.idEstufa == idEstufa).toList();

  // Ids de 32 bits, sem repetir os que ja estao agendados no sistema.
  int _proximoIdLocal() {
    final usados = _agendamentos.map((a) => a.idLocal).toSet();
    var id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);
    while (usados.contains(id)) {
      id = (id + 1).remainder(1 << 30);
    }
    return id;
  }

  Future<void> _persistir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _chave,
        AgendamentoAjuste.listaParaJson(_agendamentos),
      );
    } catch (_) {
      // Melhor esforco: a lista em memoria ja reflete a mudanca.
    }
  }

  Future<void> _agendarAvisoLocal(AgendamentoAjuste agendamento) async {
    if (!_suportado) return;
    if (!agendamento.quando.isAfter(DateTime.now())) return;
    // O produtor desligou o aviso deste evento: o ajuste continua sendo
    // agendado na nuvem, so o lembrete nao aparece.
    if (!_preferencia.notificar) return;

    await _prepararFuso();
    final android = _notificacoes
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canalUsado = _preferencia.tocarVibrar ? canalComAlarme : canal;
    await android?.createNotificationChannel(canalUsado);

    try {
      await _notificacoes.zonedSchedule(
        id: agendamento.idLocal,
        title: '${agendamento.nomeEstufa} · Hora de ajustar',
        body: 'Ajustar ${agendamento.descricao}.',
        // O instante e o que importa: convertido em UTC ele dispara na hora
        // certa qualquer que seja o fuso do aparelho. Evita depender de um plugin
        // so para descobrir o nome do fuso local.
        scheduledDate: tz.TZDateTime.from(agendamento.quando, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            canalUsado.id,
            canalUsado.name,
            channelDescription: canalUsado.description,
            importance: canalUsado.importance,
            priority: Priority.high,
            sound: canalUsado.sound,
            audioAttributesUsage: canalUsado.audioAttributesUsage,
          ),
        ),
        // Atravessa o repouso do Android. Sem isto o aviso pode atrasar bastante,
        // e um lembrete de erguer calor atrasado nao serve.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({'agendamento': agendamento.idLocal}),
      );
    } catch (erro) {
      // Alguns aparelhos recusam alarme exato sem a permissao concedida. Cai para
      // o modo aproximado em vez de perder o aviso.
      debugPrint('Alarme exato indisponivel, usando aproximado: $erro');
      try {
        await _notificacoes.zonedSchedule(
          id: agendamento.idLocal,
          title: '${agendamento.nomeEstufa} · Hora de ajustar',
          body: 'Ajustar ${agendamento.descricao}.',
          scheduledDate: tz.TZDateTime.from(agendamento.quando, tz.UTC),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              canalUsado.id,
              canalUsado.name,
              channelDescription: canalUsado.description,
              importance: canalUsado.importance,
              priority: Priority.high,
              sound: canalUsado.sound,
              audioAttributesUsage: canalUsado.audioAttributesUsage,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (erro2) {
        debugPrint('Nao foi possivel agendar o aviso: $erro2');
      }
    }
  }

  /// Avisa que o ajuste agendado nao chegou a ser registrado e ja passou da
  /// hora. Aparece na abertura do app, que e quando o app descobre.
  Future<void> _avisarNaoAplicado(AgendamentoAjuste agendamento) async {
    if (!_suportado) return;
    final android = _notificacoes
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    // Sempre no canal comum, sem alarme: e a noticia de que algo NAO aconteceu,
    // e chega quando o produtor abre o app - nao ha ninguem para acordar.
    await android?.createNotificationChannel(canal);
    try {
      await _notificacoes.show(
        id: agendamento.idLocal,
        title: 'Ajuste não aplicado — ${agendamento.nomeEstufa}',
        body:
            'O celular estava sem internet e não deu tempo de registrar '
            '${agendamento.descricao}. Confira o ajuste na estufa.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            canal.id,
            canal.name,
            channelDescription: canal.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (erro) {
      debugPrint('Nao foi possivel avisar sobre o agendamento perdido: $erro');
    }
  }

  Future<void> _prepararFuso() async {
    if (_fusoPronto) return;
    tzdata.initializeTimeZones();
    _fusoPronto = true;
  }

  Uri? _uri(String caminho) {
    final base = _cloudApiUrl.trim();
    if (base.isEmpty) return null;
    return Uri.tryParse('${base.replaceFirst(RegExp(r'/+$'), '')}$caminho');
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null && token.trim().isNotEmpty) ...{
      'Authorization': 'Bearer ${token.trim()}',
      'X-Device-Token': token.trim(),
    },
  };

  Future<String?> _registrarNaNuvem(
    AgendamentoAjuste agendamento,
    String? token,
  ) async {
    final idHardware = agendamento.idHardware;
    final uri = _uri('/agendamentos');
    if (uri == null || idHardware == null || idHardware.isEmpty) return null;

    try {
      final resposta = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode({
              'idHardware': idHardware,
              'aplicarEmMs': agendamento.quando.millisecondsSinceEpoch,
              if (agendamento.temperaturaMeta != null)
                'temperaturaMeta': agendamento.temperaturaMeta,
              if (agendamento.temperaturaDelta != null)
                'temperaturaDelta': agendamento.temperaturaDelta,
              if (agendamento.umidadeMeta != null)
                'umidadeMeta': agendamento.umidadeMeta,
              if (agendamento.umidadeDelta != null)
                'umidadeDelta': agendamento.umidadeDelta,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        debugPrint('Agendamento recusado pela nuvem (${resposta.statusCode}).');
        return null;
      }
      final corpo = jsonDecode(resposta.body);
      return corpo is Map ? corpo['id'] as String? : null;
    } catch (erro) {
      debugPrint('Nao foi possivel registrar o agendamento na nuvem: $erro');
      return null;
    }
  }

  Future<void> _removerDaNuvem(
    AgendamentoAjuste agendamento,
    String? token,
  ) async {
    final uri = _uri(
      '/agendamentos/${agendamento.id}'
      '?idHardware=${Uri.encodeComponent(agendamento.idHardware!)}',
    );
    if (uri == null) return;
    try {
      await http
          .delete(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 12));
    } catch (erro) {
      debugPrint('Nao foi possivel remover o agendamento na nuvem: $erro');
    }
  }
}
