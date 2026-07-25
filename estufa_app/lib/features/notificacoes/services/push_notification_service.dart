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

  /// Canal nativo (Kotlin, em `MainActivity`) que abre as configuracoes de
  /// "Nao perturbe" do sistema. O plugin so as abre quando a permissao ainda
  /// falta; ja concedida, ele nao faz nada, entao o botao "Ver nas
  /// configuracoes" precisa deste caminho.
  static const MethodChannel _canalNaoPerturbe = MethodChannel(
    'sentinela/nao_perturbe',
  );

  static const AndroidNotificationChannel _canalAlertas =
      AndroidNotificationChannel(
        'sentinela_alertas',
        'Alertas cr\u00edticos',
        description: 'Alertas cr\u00edticos',
        importance: Importance.high,
      );

  /// Temperatura fora da faixa: toca em volume de **alarme**, como o incendio.
  /// E de madrugada que esse aviso precisa acordar alguem, e o volume de
  /// notificacao costuma estar baixo justamente nessa hora.
  ///
  /// Mesma mensagem, sem som nem vibracao: para quem desligou "Tocar" naquele
  /// evento. Existe porque, com o app FECHADO, o som pertence ao canal - nao da
  /// para silenciar um aviso avulso. O servidor escolhe este canal ao ver a
  /// preferencia do aparelho.
  /// **Tem que casar com `CANAL_SILENCIOSO` em `estufa_server/push.js`.**
  static const AndroidNotificationChannel _canalSilencioso =
      AndroidNotificationChannel(
        'sentinela_silencioso_v1',
        'Avisos sem som',
        description: 'Avisos que o produtor pediu para não tocar.',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      );

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

  static AndroidNotificationChannel _canalTemperaturaCom({
    required bool furarNaoPerturbe,
  }) => AndroidNotificationChannel(
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
    bypassDnd: furarNaoPerturbe,
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
  static AndroidNotificationChannel _canalCriticoCom({
    required bool furarNaoPerturbe,
  }) => AndroidNotificationChannel(
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
    bypassDnd: furarNaoPerturbe,
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

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notificacoesLocais
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
    final podeFurarNaoPerturbe =
        await android?.hasNotificationPolicyAccess() ?? false;

    await android?.createNotificationChannel(_canalAlertas);
    await android?.createNotificationChannel(
      _canalCriticoCom(furarNaoPerturbe: podeFurarNaoPerturbe),
    );
    await android?.createNotificationChannel(
      _canalTemperaturaCom(furarNaoPerturbe: podeFurarNaoPerturbe),
    );
    await android?.createNotificationChannel(_canalSilencioso);
  }

  /// Se o canal de incêndio já pode tocar com o aparelho em "Não perturbe".
  Future<bool> get podeFurarNaoPerturbe async =>
      await _android?.hasNotificationPolicyAccess() ?? false;

  /// Leva o produtor à tela do sistema onde ele libera o app a furar o "Não
  /// perturbe", e recria o canal para o bypass valer.
  ///
  /// Recriar é necessário porque o Android congela a configuração de um canal
  /// existente. Em algumas versões o sistema restaura os ajustes do canal
  /// apagado; nesses aparelhos pode ser preciso ligar na mão, em
  /// Configurações → Notificações → Incêndio.
  Future<bool> solicitarPermissaoNaoPerturbe() async {
    final android = _android;
    if (android == null) return false;
    try {
      final concedido = await android.requestNotificationPolicyAccess() ?? false;
      if (!concedido) return false;
      await android.deleteNotificationChannel(channelId: canalCriticoId);
      await android.createNotificationChannel(
        _canalCriticoCom(furarNaoPerturbe: true),
      );
      // A temperatura tambem acorda de madrugada, entao ela furа o "Nao
      // perturbe" pelo mesmo motivo do fogo.
      await android.deleteNotificationChannel(channelId: canalTemperaturaId);
      await android.createNotificationChannel(
        _canalTemperaturaCom(furarNaoPerturbe: true),
      );
      return true;
    } catch (erro) {
      debugPrint('Não foi possível liberar o Não perturbe: $erro');
      return false;
    }
  }

  /// Abre a tela do sistema de acesso ao "Não perturbe" sem depender do estado
  /// da permissão. Serve ao botão "Ver nas configurações", quando o acesso já
  /// está concedido e o produtor quer conferir ou revogar.
  Future<bool> abrirAcessoNaoPerturbe() async {
    if (!_androidCompativel) return false;
    try {
      final aberto = await _canalNaoPerturbe.invokeMethod<bool>(
        'abrirConfiguracoes',
      );
      return aberto ?? false;
    } catch (erro) {
      debugPrint('Não foi possível abrir o Não perturbe: $erro');
      return false;
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

  Future<void> _registrarDispositivo({
    String? idHardware,
    String? tokenAcesso,
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
      const sempreAvisam = {'incendio', 'semComunicacao'};
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
    // Incendio e temperatura fora da faixa sao os dois que precisam ACORDAR: o
    // toque e a sirene longa, em volume de alarme, nao um bipe que passa
    // despercebido de madrugada.
    final acorda = critico || evento == EventoNotificacao.alarmeProcesso;

    // Com o app aberto quem monta a notificacao e este codigo; com o app
    // fechado quem monta e o Android, so com o que esta no canal. Por isso o
    // som de alarme aparece nos dois lugares - senao o alerta seria forte de
    // madrugada e fraco com o app na mao.
    final detalhes = NotificationDetails(
      android: AndroidNotificationDetails(
        acorda
            ? (critico ? canalCriticoId : canalTemperaturaId)
            : _canalAlertas.id,
        acorda
            ? (critico ? 'Incêndio' : 'Temperatura fora da faixa')
            : _canalAlertas.name,
        channelDescription: acorda ? null : _canalAlertas.description,
        importance: acorda ? Importance.max : Importance.high,
        priority: acorda ? Priority.max : Priority.high,
        playSound: opcao.tocarVibrar,
        sound: acorda && opcao.tocarVibrar
            ? const RawResourceAndroidNotificationSound('alarme_estufa')
            : null,
        audioAttributesUsage: acorda
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        enableVibration: opcao.tocarVibrar,
        silent: !opcao.tocarVibrar,
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
