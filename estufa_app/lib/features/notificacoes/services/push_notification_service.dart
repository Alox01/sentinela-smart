import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../../models/estufa_entity.dart';
import '../../../services/isar_service.dart';
import '../models/preferencias_notificacao.dart';
import 'preferencias_notificacao_service.dart';
import 'silenciamento_estufas.dart';

bool get _androidCompativel =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

@pragma('vm:entry-point')
Future<void> tratarPushEmSegundoPlano(RemoteMessage mensagem) async {
  if (!_androidCompativel) return;
  await Firebase.initializeApp();
}

void registrarTratamentoPushEmSegundoPlano() {
  if (_androidCompativel) {
    FirebaseMessaging.onBackgroundMessage(tratarPushEmSegundoPlano);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _cloudApiUrl = String.fromEnvironment('CLOUD_API_URL');
  static const String _apiToken = String.fromEnvironment('ESTUFA_API_TOKEN');

  /// Canal nativo (Kotlin, em `MainActivity`) para o que o Flutter nao expoe.
  /// Hoje so o modo de som do celular — o app precisa saber se esta mudo para
  /// avisar que nenhum alerta vai tocar, nem o de incendio.
  static const MethodChannel _canalSistema = MethodChannel(
    'sentinela/nao_perturbe',
  );

  static const AndroidNotificationChannel _canalAlertas =
      AndroidNotificationChannel(
        'sentinela_alertas',
        'Alertas cr\u00edticos',
        description: 'Alertas cr\u00edticos',
        importance: Importance.high,
      );

  /// Temperatura acima do limite de incendio (175 °F). Evento separado do sensor
  /// de chama porque as causas sao independentes - o produtor pode querer
  /// desligar o aviso de uma sem perder o da outra. Toca como alarme, igual ao
  /// fogo.
  /// **Tem que casar com `CANAL_TEMP_MUITO_ALTA` em `estufa_server/push.js`.**
  static const String canalTempMuitoAltaId = 'sentinela_temp_muito_alta_v1';

  static AndroidNotificationChannel _canalTempMuitoAlta() =>
      AndroidNotificationChannel(
        canalTempMuitoAltaId,
        'Temperatura muito elevada',
        description:
            'Toca como alarme quando a temperatura passa do limite de risco '
            'de incêndio.',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarme_estufa'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 400, 1000, 400, 1000]),
      );

  /// Aparelho mudo tira da cama: as 3h da manha pode ser queda de energia
  /// com a estufada em andamento. Antes este aviso ia no canal do INCENDIO
  /// (o watchdog o marca como critico) - acordava, mas aparecia como "Incendio"
  /// nas configuracoes do Android, e o produtor nao conseguia silenciar um sem
  /// perder o outro.
  /// **Tem que casar com `CANAL_SEM_COMUNICACAO` em `estufa_server/push.js`.**
  static const String canalSemComunicacaoId = 'sentinela_sem_comunicacao_v1';

  static AndroidNotificationChannel _canalSemComunicacao() =>
      AndroidNotificationChannel(
        canalSemComunicacaoId,
        'Sem comunicação',
        description:
            'Toca como alarme, em volume alto, quando a estufa para de '
            'se comunicar.',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarme_estufa'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([
          0,
          400,
          200,
          400,
          200,
          400,
          200,
          400,
        ]),
      );

  /// Temperatura fora da faixa: toca em volume de **alarme**, como o incendio.
  /// E de madrugada que esse aviso precisa acordar alguem, e o volume de
  /// notificacao costuma estar baixo justamente nessa hora.
  ///
  /// Canal separado do incendio, e nao o mesmo, porque cada um tem a sua
  /// historia de configuracao no Android: o produtor pode querer silenciar um
  /// sem perder o outro, e um canal ja criado nao se reconfigura.
  ///
  /// Usa a mesma sirene do incendio - e o unico som longo disponivel, e o toque
  /// precisa ser **persistente** para acordar, nao um bipe. A vibracao e mais
  /// espacada que a do fogo, o que ajuda a distinguir de perto; pelo som, os
  /// dois sao parecidos (ver ressalva em NOTIFICACOES_PUSH.md).
  /// **Tem que casar com `CANAL_TEMPERATURA` em `estufa_server/push.js`.**
  static const String canalTemperaturaId = 'sentinela_temperatura_v1';

  static AndroidNotificationChannel _canalTemperatura() =>
      AndroidNotificationChannel(
        canalTemperaturaId,
        'Temperatura fora da faixa',
        description:
            'Toca como alarme, em volume alto, quando a temperatura sai da '
            'faixa do ajuste.',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarme_estufa'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 600, 800, 600, 800]),
      );

  /// O id mudou de `sentinela_critico` para `_v2` de proposito: o Android nao
  /// deixa alterar som nem importancia de um canal ja criado, entao quem ja
  /// tinha o app continuaria com o bipe curto padrao. Canal novo e a unica
  /// forma de a mudanca valer para todo mundo. **Tem que casar com o
  /// `channelId` que o servidor envia** (`estufa_server/push.js`).
  static const String canalCriticoId = 'sentinela_critico_v2';

  /// Som longo e em volume de ALARME (nao de notificacao). Essa distincao e o
  /// ponto principal: o volume de notificacao costuma ficar baixo, enquanto o
  /// de alarme e o que as pessoas mantem alto justamente para acordar.
  static AndroidNotificationChannel _canalCritico() =>
      AndroidNotificationChannel(
        canalCriticoId,
        'Inc\u00eandio',
        description:
            'Toca como alarme, em volume alto, mesmo de madrugada. '
            'Reservado a inc\u00eandio.',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarme_estufa'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      );

  final FlutterLocalNotificationsPlugin _notificacoesLocais =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _mensagemSubscription;
  String? _tokenPush;
  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado || !_androidCompativel) return;

    try {
      await Firebase.initializeApp();
      await _inicializarNotificacoesLocais();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      _tokenPush = await messaging.getToken();
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        _tokenPush = token;
        unawaited(sincronizarEstufas());
      });
      _mensagemSubscription = FirebaseMessaging.onMessage.listen((mensagem) {
        unawaited(_mostrarMensagemEmPrimeiroPlano(mensagem));
      });
      PreferenciasNotificacaoService.instance.addListener(
        _preferenciasAlteradas,
      );

      _inicializado = true;
      await sincronizarEstufas();
    } catch (erro) {
      debugPrint('Push indisponível neste dispositivo: $erro');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notificacoesLocais
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _inicializarNotificacoesLocais() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notificacoesLocais.initialize(settings: settings);

    final android = _android;
    // A permissao vem ANTES de criar os canais: um canal criado com
    // `bypassDnd: true` sem a permissao concedida nasce sem o bypass, calado,
    // e o Android nao deixa corrigir depois sem recriar o canal.
    await android?.requestNotificationsPermission();

    await android?.createNotificationChannel(_canalAlertas);
    await android?.createNotificationChannel(_canalCritico());
    await android?.createNotificationChannel(_canalTemperatura());
    await android?.createNotificationChannel(_canalSemComunicacao());
    await android?.createNotificationChannel(_canalTempMuitoAlta());
  }

  /// Modo de som do celular: `normal`, `vibrar` ou `silencioso`.
  ///
  /// No silencioso **nenhum aviso toca**, nem o de incêndio — medido no
  /// aparelho, e é o Android, não o app. Como é o estado em que se entra sem
  /// querer (baixando o volume, sobrando de uma reunião), a tela avisa em vez de
  /// deixar o alerta simplesmente não tocar de madrugada.
  Future<String> modoDeSom() async {
    if (!_androidCompativel) return 'normal';
    try {
      final modo = await _canalSistema.invokeMethod<String>('modoDeSom');
      return modo ?? 'normal';
    } catch (erro) {
      debugPrint('Nao foi possivel ler o modo de som: $erro');
      return 'normal';
    }
  }

  void _preferenciasAlteradas() {
    unawaited(sincronizarEstufas());
  }

  Future<void> sincronizarEstufas() async {
    if (!_inicializado || _tokenPush == null) return;
    try {
      final estufas = await IsarService.instance.listarEstufas();
      for (final estufa in estufas) {
        await registrarEstufa(estufa);
      }
    } catch (erro) {
      debugPrint('Não foi possível sincronizar o push: $erro');
    }
  }

  Future<void> registrarEstufa(EstufaEntity estufa) => _registrarDispositivo(
    idHardware: estufa.idHardware?.trim(),
    tokenAcesso: estufa.tokenAcesso,
    nome: estufa.nome.trim(),
  );

  /// Reenvia as preferencias de um aparelho (ex.: depois de silenciar ou religar
  /// os avisos daquela estufa). O servidor passa a suprimir ou liberar os avisos
  /// desse aparelho conforme o conjunto enviado.
  Future<void> atualizarPreferenciasDispositivo({
    required String idHardware,
    String? tokenAcesso,
  }) => _registrarDispositivo(
    idHardware: idHardware.trim(),
    tokenAcesso: tokenAcesso,
  );

  /// [nome] vai junto para o servidor poder dizer *qual* estufa esta alertando:
  /// o titulo do push e montado la, e o nome so existe aqui no celular. Vai
  /// nulo quando quem chama nao o tem em maos (reenvio de preferencias) - e o
  /// servidor entao preserva o que ja guardou.
  Future<void> _registrarDispositivo({
    String? idHardware,
    String? tokenAcesso,
    String? nome,
  }) async {
    final token = _tokenPush;
    final uri = _uriPush('/push/dispositivos');
    if (!_inicializado ||
        token == null ||
        idHardware == null ||
        idHardware.isEmpty ||
        uri == null) {
      return;
    }

    await SilenciamentoEstufas.instance.carregar();

    try {
      final resposta = await http
          .post(
            uri,
            headers: _headersJson(tokenAcesso),
            body: jsonEncode({
              'tokenPush': token,
              'idHardware': idHardware,
              'plataforma': 'android',
              'preferencias': _prefsParaDispositivo(idHardware),
              if (nome != null && nome.isNotEmpty) 'nome': nome,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        debugPrint('Registro do push recusado (${resposta.statusCode}).');
      }
    } catch (erro) {
      debugPrint('Registro do push adiado: $erro');
    }
  }

  /// Preferencias a enviar para UM aparelho: as globais, mas se aquela estufa
  /// estiver silenciada, mantem so os avisos que nunca calam (incendio e sem
  /// comunicacao) e desliga o resto — sem tocar nas preferencias globais.
  Map<String, dynamic> _prefsParaDispositivo(String idHardware) {
    final base = PreferenciasNotificacaoService.instance.preferencias.toJson();
    if (SilenciamentoEstufas.instance.silenciada(idHardware)) {
      // Os dois avisos de risco de fogo e o de aparelho mudo atravessam o
      // silenciamento: sao os que valem uma ida a estufa mesmo de madrugada.
      const sempreAvisam = {
        'incendio',
        'temperaturaMuitoAlta',
        'semComunicacao',
      };
      for (final chave in base.keys.toList()) {
        if (!sempreAvisam.contains(chave)) {
          base[chave] = {'notificar': false, 'tocarVibrar': false};
        }
      }
    }
    return base;
  }

  Future<void> removerEstufa(EstufaEntity estufa) async {
    final token = _tokenPush;
    final idHardware = estufa.idHardware?.trim();
    final uri = _uriPush('/push/dispositivos');
    if (!_inicializado ||
        token == null ||
        idHardware == null ||
        idHardware.isEmpty ||
        uri == null) {
      return;
    }

    try {
      await http
          .delete(
            uri,
            headers: _headersJson(estufa.tokenAcesso),
            body: jsonEncode({'tokenPush': token, 'idHardware': idHardware}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (erro) {
      debugPrint('Remoção do push adiada: $erro');
    }
  }

  Uri? _uriPush(String caminho) {
    final base = _cloudApiUrl.trim();
    if (base.isEmpty) return null;
    return Uri.tryParse('${base.replaceFirst(RegExp(r'/+$'), '')}$caminho');
  }

  /// A chave da propria estufa vem primeiro: e ela que o produtor cadastra no
  /// app e que o servidor espera. O token de build (`--dart-define`) e so
  /// fallback - so com ele o registro ia sem autenticacao e levava 401 calado.
  Map<String, String> _headersJson([String? tokenEstufa]) {
    final token = (tokenEstufa?.trim().isNotEmpty ?? false)
        ? tokenEstufa!.trim()
        : _apiToken.trim();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) ...{
        'Authorization': 'Bearer $token',
        'X-Device-Token': token,
      },
    };
  }

  /// Cala a sirene dos avisos ao abrir o app.
  ///
  /// A sirene dura 30 s e so parava ao puxar a barra de notificacoes — mas quem
  /// abriu o app **ja viu** o problema, e continuar tocando enquanto ele olha a
  /// tela so ensina o produtor a silenciar tudo. Abrir o app e o unico gesto que
  /// significa "eu vi" sem ambiguidade: destrancar o celular pode ser para outra
  /// coisa, e ai o aviso morreria sem ninguem ter lido.
  ///
  /// So os canais que tocam como alarme sao cancelados. A sirene do proprio
  /// aparelho, na estufa, nao e afetada — ela e hardware.
  Future<void> calarAvisosSonoros() async {
    if (!_androidCompativel) return;
    // Cancela TUDO, sem tentar escolher. A versao anterior listava as
    // notificacoes ativas para cancelar so as que tocam e preservar as
    // informativas na barra - e falhou justamente com o alarme de incendio,
    // porque essa consulta nem sempre enxerga o que o Android postou a partir
    // do push. Preservar um lembrete na barra nao vale o risco de a sirene nao
    // parar, e o que sai da barra continua visivel dentro do app.
    try {
      await _notificacoesLocais.cancelAll();
    } catch (erro) {
      debugPrint('Nao foi possivel calar os avisos: $erro');
    }
  }

  /// Canal de alarme de cada evento. Espelha `CANAIS_QUE_ACORDAM` do servidor —
  /// se os dois divergirem, o Android entrega no canal padrao e o alerta perde o
  /// som de alarme sem erro nenhum aparecer.
  static String _canalDoEvento(EventoNotificacao evento) => switch (evento) {
    EventoNotificacao.incendio => canalCriticoId,
    EventoNotificacao.temperaturaMuitoAlta => canalTempMuitoAltaId,
    EventoNotificacao.alarmeProcesso => canalTemperaturaId,
    EventoNotificacao.semComunicacao => canalSemComunicacaoId,
    // O lembrete de agendamento e local, montado pelo AgendamentoService; nunca
    // chega por push. Cai no canal comum se algum dia chegar.
    EventoNotificacao.ajusteAgendado => _canalAlertas.id,
  };

  Future<void> _mostrarMensagemEmPrimeiroPlano(RemoteMessage mensagem) async {
    final evento = _eventoDaMensagem(mensagem);
    final opcao = PreferenciasNotificacaoService.instance.preferencias.opcao(
      evento,
    );
    if (!opcao.notificar) return;

    final titulo = mensagem.notification?.title ?? evento.titulo;
    final corpo =
        mensagem.notification?.body ??
        mensagem.data['mensagem']?.toString() ??
        evento.descricao;
    final critico = evento.critico;
    // Quem acorda: fogo, temperatura fora da faixa e aparelho mudo. O servidor
    // manda isso resolvido porque "sem comunicacao" e "voltou a se comunicar"
    // compartilham o mesmo evento, e so um dos dois deve tocar - daqui nao daria
    // para saber qual e.
    //
    // "Tocar" desligado nao silencia o aviso: ele so deixa de ser alarme e passa
    // a ser notificacao comum, com bipe e vibracao seguindo a configuracao do
    // proprio celular - como em qualquer app.
    final acorda =
        opcao.tocarVibrar &&
        (mensagem.data['acorda'] == 'true' ||
            critico ||
            evento == EventoNotificacao.alarmeProcesso);
    // Um canal por assunto, para o produtor silenciar um sem perder os outros
    // nas configuracoes do Android.
    final canalId = !acorda ? _canalAlertas.id : _canalDoEvento(evento);

    // Com o app aberto quem monta a notificacao e este codigo; com o app
    // fechado quem monta e o Android, so com o que esta no canal. Por isso o
    // som de alarme aparece nos dois lugares - senao o alerta seria forte de
    // madrugada e fraco com o app na mao.
    final detalhes = NotificationDetails(
      android: AndroidNotificationDetails(
        canalId,
        acorda ? evento.titulo : _canalAlertas.name,
        channelDescription: acorda ? null : _canalAlertas.description,
        importance: acorda ? Importance.max : Importance.high,
        priority: acorda ? Priority.max : Priority.high,
        // Sem `silent`: mesmo com o toque desligado o aviso continua sendo uma
        // notificacao comum. Quem decide se ela bipa, vibra ou so aparece na
        // tela e a configuracao do celular, nao o app.
        playSound: true,
        sound: acorda
            ? const RawResourceAndroidNotificationSound('alarme_estufa')
            : null,
        audioAttributesUsage: acorda
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        enableVibration: true,
      ),
    );
    await _notificacoesLocais.show(
      id:
          mensagem.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: titulo,
      body: corpo,
      notificationDetails: detalhes,
      payload: jsonEncode(mensagem.data),
    );
  }

  EventoNotificacao _eventoDaMensagem(RemoteMessage mensagem) {
    final chave = mensagem.data['evento']?.toString();
    return EventoNotificacao.values.firstWhere(
      (evento) => evento.chave == chave,
      orElse: () => EventoNotificacao.alarmeProcesso,
    );
  }

  Future<void> encerrar() async {
    PreferenciasNotificacaoService.instance.removeListener(
      _preferenciasAlteradas,
    );
    await _tokenSubscription?.cancel();
    await _mensagemSubscription?.cancel();
    _inicializado = false;
  }
}
