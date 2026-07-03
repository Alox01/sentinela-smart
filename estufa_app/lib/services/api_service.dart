import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'isar_service.dart';

enum ApiCommandFailure {
  none,
  offline,
  unauthorized,
  invalidRequest,
  serverError,
}

class ApiService {
  static const String _cloudPadrao = String.fromEnvironment(
    'CLOUD_API_URL',
    defaultValue: '',
  );
  static const String _tokenPadrao = String.fromEnvironment(
    'ESTUFA_API_TOKEN',
    defaultValue: '',
  );
  static const String _tokenLegado = String.fromEnvironment(
    'API_AUTH_TOKEN',
    defaultValue: '',
  );

  final String localBaseUrl;
  final String? localPort80FallbackUrl;
  final String? cloudBaseUrl;
  final String? authToken;

  String? _baseUrlAtiva;
  DateTime _ultimaResolucao = DateTime.fromMillisecondsSinceEpoch(0);
  ApiCommandFailure _ultimaFalhaComando = ApiCommandFailure.none;

  ApiService(String ip, {String? cloudUrl, String? token})
    : localBaseUrl = _normalizarBaseUrl(ip),
      localPort80FallbackUrl = _normalizarFallbackPorta80(ip),
      cloudBaseUrl = _normalizarCloudUrl(cloudUrl ?? _cloudPadrao),
      authToken = _normalizarToken(
        token ?? (_tokenPadrao.isNotEmpty ? _tokenPadrao : _tokenLegado),
      );

  String get modoConexao {
    final ativa = _baseUrlAtiva;
    if (ativa == null) return 'OFFLINE';
    if (ativa == localBaseUrl || ativa == localPort80FallbackUrl) {
      return 'LOCAL';
    }
    return 'NUVEM';
  }

  String? get baseUrlAtiva => _baseUrlAtiva;

  bool get temTokenConfigurado => authToken != null && authToken!.isNotEmpty;

  ApiCommandFailure get ultimaFalhaComando => _ultimaFalhaComando;

  bool get temNuvemConfigurada =>
      cloudBaseUrl != null && cloudBaseUrl!.isNotEmpty;

  Future<Map<String, dynamic>?> buscarStatus() async {
    final response = await _getComFallback('/status');
    if (response?.statusCode == 200) {
      final dados = _decodificarMapa(response!.body);
      if (dados == null) return null;
      final pendenciasSincronizadas = await sincronizarComandosPendentes();

      if (pendenciasSincronizadas > 0) {
        final responseAtualizada = await _getComFallback('/status');
        if (responseAtualizada?.statusCode == 200) {
          return _decodificarMapa(responseAtualizada!.body);
        }
      }

      return dados;
    }

    final responseRaiz = await _getComFallback('/');
    if (responseRaiz?.statusCode == 200) {
      final dadosRaiz = _decodificarMapa(responseRaiz!.body);
      if (dadosRaiz == null) return null;
      return _adaptarStatusRaizEsp32(dadosRaiz);
    }

    return null;
  }

  Future<bool> enviarSincronizacao(
    Map<String, dynamic> dadosParaAtualizar, {
    bool enfileirarSeOffline = true,
  }) async {
    _ultimaFalhaComando = ApiCommandFailure.none;
    final response = await _postComFallback(
      '/sincronizar',
      headers: _headers({'Content-Type': 'application/json'}),
      body: jsonEncode(dadosParaAtualizar),
    );

    if (response != null && _respostaSucesso(response.statusCode)) {
      return true;
    }

    if (response != null) {
      _ultimaFalhaComando = switch (response.statusCode) {
        401 || 403 => ApiCommandFailure.unauthorized,
        >= 400 && < 500 => ApiCommandFailure.invalidRequest,
        _ => ApiCommandFailure.serverError,
      };

      if (_erroNaoRecuperavel(response.statusCode)) {
        debugPrint(
          'Comando recusado pelo servidor (${response.statusCode}). '
          'Nao sera enfileirado.',
        );
        return false;
      }
    } else {
      _ultimaFalhaComando = ApiCommandFailure.offline;
    }

    if (enfileirarSeOffline) {
      await IsarService.instance.adicionarComandoPendente(
        ipEstufa: localBaseUrl,
        payload: dadosParaAtualizar,
      );
      debugPrint('Comando enfileirado para sincronizacao posterior.');
    }
    return false;
  }

  Future<void> silenciarAlarme() async {
    await enviarSincronizacao({
      'modoSilencioso': true,
      'modoSilenciosoTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<ApiConnectionProbe>> verificarConexoes() async {
    final probes = <ApiConnectionProbe>[];
    for (final base in _candidatas()) {
      probes.add(
        ApiConnectionProbe(
          baseUrl: base,
          nome: base == localBaseUrl || base == localPort80FallbackUrl
              ? 'Local'
              : 'Nuvem',
          online: await _estaOnline(base),
        ),
      );
    }
    return probes;
  }

  Future<int> sincronizarComandosPendentes({int limite = 100}) async {
    final pendencias = await IsarService.instance.listarPendenciasPorIp(
      localBaseUrl,
      limite: limite,
    );
    if (pendencias.isEmpty) return 0;

    final idsSincronizados = <int>[];
    for (final pendencia in pendencias) {
      final payload = _parsePayload(pendencia.payloadJson);
      if (payload == null) {
        idsSincronizados.add(pendencia.id);
        continue;
      }

      final enviado = await enviarSincronizacao(
        payload,
        enfileirarSeOffline: false,
      );
      if (!enviado) break;
      idsSincronizados.add(pendencia.id);
    }

    await IsarService.instance.removerPendenciasPorIds(idsSincronizados);
    return idsSincronizados.length;
  }

  Future<http.Response?> _getComFallback(String path) async {
    final ativa = await _resolverBaseAtiva();
    if (ativa == null) return null;

    try {
      return await http
          .get(Uri.parse('$ativa$path'), headers: _headers())
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      _baseUrlAtiva = null;
      final fallback = await _resolverBaseAtiva(force: true);
      if (fallback == null) return null;

      try {
        return await http
            .get(Uri.parse('$fallback$path'), headers: _headers())
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        return null;
      }
    }
  }

  Future<http.Response?> _postComFallback(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final ativa = await _resolverBaseAtiva();
    if (ativa == null) return null;

    try {
      return await http
          .post(Uri.parse('$ativa$path'), headers: headers, body: body)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      _baseUrlAtiva = null;
      final fallback = await _resolverBaseAtiva(force: true);
      if (fallback == null) return null;

      try {
        return await http
            .post(Uri.parse('$fallback$path'), headers: headers, body: body)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        return null;
      }
    }
  }

  Future<String?> _resolverBaseAtiva({bool force = false}) async {
    final agora = DateTime.now();
    final cacheValido =
        agora.difference(_ultimaResolucao) < const Duration(seconds: 8);
    if (!force && _baseUrlAtiva != null && cacheValido) {
      return _baseUrlAtiva;
    }

    for (final base in _candidatas()) {
      if (await _estaOnline(base)) {
        _baseUrlAtiva = base;
        _ultimaResolucao = agora;
        return base;
      }
    }

    _baseUrlAtiva = null;
    _ultimaResolucao = agora;
    return null;
  }

  Future<bool> _estaOnline(String base) async {
    try {
      final response = await http
          .get(Uri.parse('$base/status'), headers: _headers())
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) return true;
    } catch (_) {
      // Alguns prototipos ESP32 respondem o JSON diretamente na rota raiz.
    }

    try {
      final response = await http
          .get(Uri.parse('$base/'), headers: _headers())
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200 &&
          _decodificarMapa(response.body) != null;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _decodificarMapa(String body) {
    try {
      final json = jsonDecode(body);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _adaptarStatusRaizEsp32(Map<String, dynamic> dados) {
    final temperatura = _numero(dados['temperaturaF']) ?? 0;
    final umidade = _numero(dados['umidade']) ?? 0;
    final ajusteTemperatura = _numero(dados['temperaturaAlvoF']) ?? temperatura;
    final ajusteUmidade =
        _numero(dados['umidadeAlvo']) ??
        _numero(dados['umidadeMeta']) ??
        umidade;
    final alertaTemperatura = _booleano(dados['alertaTemperatura']);
    final alertaLuz = _booleano(dados['alertaLuz']);
    final leituraOk = _booleano(dados['leituraOk']);
    final alertaLigado = alertaTemperatura || alertaLuz || !leituraOk;

    return {
      'status': {
        'idHardware': 'ESP32_REAL',
        'timestampLeitura': DateTime.now().millisecondsSinceEpoch,
        'temperaturaAtual': temperatura,
        'umidadeAtual': umidade,
        'temEnergia': true,
        'temInternet': true,
        'sinalWifi': 100,
        'alertaIncendio': alertaLigado,
        'alertaIncendioLigado': alertaLigado,
        'aquecedorLigado': _booleano(dados['ledControleLigado']),
        'umidificadorLigado': _booleano(dados['mostrandoUmidade']),
        'faseAtual': 'Leitura real',
        'aviso': leituraOk ? 'ESP32 conectado' : 'Falha na leitura do sensor',
        'corStatus': leituraOk ? 'green' : 'red',
      },
      'config': {
        'idHardware': 'ESP32_REAL',
        'tempMeta': ajusteTemperatura,
        'tempTimestamp': DateTime.now().millisecondsSinceEpoch,
        'umidadeMeta': ajusteUmidade,
        'umidTimestamp': DateTime.now().millisecondsSinceEpoch,
        'modoSilencioso': _booleano(dados['buzzerSilenciado']),
        'modoSilenciosoTimestamp': 0,
      },
    };
  }

  double? _numero(Object? valor) {
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor.replaceAll(',', '.'));
    return null;
  }

  bool _booleano(Object? valor) {
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    if (valor is String) return valor.toLowerCase() == 'true';
    return false;
  }

  List<String> _candidatas() {
    final lista = <String>[localBaseUrl];
    if (localPort80FallbackUrl != null &&
        localPort80FallbackUrl != localBaseUrl) {
      lista.add(localPort80FallbackUrl!);
    }
    if (cloudBaseUrl != null &&
        cloudBaseUrl != localBaseUrl &&
        cloudBaseUrl != localPort80FallbackUrl) {
      lista.add(cloudBaseUrl!);
    }
    return lista;
  }

  static String _normalizarBaseUrl(String ipOuUrl) {
    final valor = ipOuUrl.trim();
    if (valor.isEmpty) return '';

    final temProtocolo =
        valor.startsWith('http://') || valor.startsWith('https://');
    final uri = Uri.tryParse(temProtocolo ? valor : 'http://$valor');

    if (uri != null && uri.host.isNotEmpty) {
      final porta = uri.hasPort
          ? uri.port
          : (uri.scheme == 'https' ? null : 3000);
      final normalizada = Uri(
        scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
        host: uri.host,
        port: porta,
      ).toString();
      return normalizada.endsWith('/')
          ? normalizada.substring(0, normalizada.length - 1)
          : normalizada;
    }

    final semBarra = valor.endsWith('/')
        ? valor.substring(0, valor.length - 1)
        : valor;
    final temPorta = RegExp(r':\d+$').hasMatch(semBarra);
    return 'http://$semBarra${temPorta ? '' : ':3000'}';
  }

  static String? _normalizarFallbackPorta80(String ipOuUrl) {
    final valor = ipOuUrl.trim();
    if (valor.isEmpty) return null;

    final temProtocolo =
        valor.startsWith('http://') || valor.startsWith('https://');
    final uri = Uri.tryParse(temProtocolo ? valor : 'http://$valor');
    if (uri == null || uri.host.isEmpty || uri.hasPort) return null;
    if (uri.scheme == 'https') return null;

    return 'http://${uri.host}:80';
  }

  static String? _normalizarCloudUrl(String? cloudUrl) {
    final valor = cloudUrl?.trim() ?? '';
    if (valor.isEmpty) return null;
    return valor.endsWith('/') ? valor.substring(0, valor.length - 1) : valor;
  }

  static String? _normalizarToken(String? token) {
    final valor = token?.trim() ?? '';
    if (valor.isEmpty) return null;
    return valor;
  }

  bool _respostaSucesso(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  bool _erroNaoRecuperavel(int statusCode) =>
      statusCode == 401 ||
      statusCode == 403 ||
      (statusCode >= 400 && statusCode < 500);

  Map<String, String> _headers([Map<String, String>? base]) {
    final headers = <String, String>{...?base};
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['X-Device-Token'] = token;
    }
    return headers;
  }

  Map<String, dynamic>? _parsePayload(String payloadJson) {
    try {
      final parsed = jsonDecode(payloadJson);
      if (parsed is Map<String, dynamic>) return parsed;
      return null;
    } catch (_) {
      return null;
    }
  }
}

class ApiConnectionProbe {
  final String nome;
  final String baseUrl;
  final bool online;

  const ApiConnectionProbe({
    required this.nome,
    required this.baseUrl,
    required this.online,
  });
}
