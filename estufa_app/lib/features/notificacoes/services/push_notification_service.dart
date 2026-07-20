import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../../models/estufa_entity.dart';
import '../../../services/isar_service.dart';
import '../models/preferencias_notificacao.dart';
import 'preferencias_notificacao_service.dart';

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

  static const AndroidNotificationChannel _canalAlertas =
      AndroidNotificationChannel(
        'sentinela_alertas',
        'Alertas cr\u00edticos',
        description: 'Alertas cr\u00edticos',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _canalCritico =
      AndroidNotificationChannel(
        'sentinela_critico',
        'Alertas cr\u00edticos',
        description: 'Avisos cr\u00edticos de inc\u00eandio ou chama.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
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

  Future<void> _inicializarNotificacoesLocais() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notificacoesLocais.initialize(settings: settings);

    final android = _notificacoesLocais
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_canalAlertas);
    await android?.createNotificationChannel(_canalCritico);
    await android?.requestNotificationsPermission();
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

  Future<void> registrarEstufa(EstufaEntity estufa) async {
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
      final resposta = await http
          .post(
            uri,
            headers: _headersJson(),
            body: jsonEncode({
              'tokenPush': token,
              'idHardware': idHardware,
              'plataforma': 'android',
              'preferencias': PreferenciasNotificacaoService
                  .instance
                  .preferencias
                  .toJson(),
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
            headers: _headersJson(),
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

  Map<String, String> _headersJson() => {
    'Content-Type': 'application/json',
    if (_apiToken.trim().isNotEmpty)
      'Authorization': 'Bearer ${_apiToken.trim()}',
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
    final canal = critico ? _canalCritico : _canalAlertas;

    final detalhes = NotificationDetails(
      android: AndroidNotificationDetails(
        canal.id,
        canal.name,
        channelDescription: canal.description,
        importance: critico ? Importance.max : Importance.high,
        priority: critico ? Priority.max : Priority.high,
        playSound: opcao.tocarVibrar,
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
