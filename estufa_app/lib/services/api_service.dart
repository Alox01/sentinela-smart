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

  // Ultima conexao que funcionou por estufa, compartilhada entre as telas
  // (card da home, monitoramento). Evita re-sondar tudo do zero a cada
  // instancia e reduz o tempo ate a primeira leitura.
  static final Map<String, _ResolucaoConexao> _ultimaConexaoBoa = {};
  static const Duration _validadeResolucaoCompartilhada = Duration(seconds: 30);

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
      ) {
    final lembrada = _ultimaConexaoBoa[localBaseUrl];
    if (lembrada != null &&
        DateTime.now().difference(lembrada.quando) <
            _validadeResolucaoCompartilhada) {
      _baseUrlAtiva = lembrada.base;
      _ultimaResolucao = lembrada.quando;
    }
  }

  // A nuvem (Render + internet movel) responde mais devagar que a rede local;
  // usar o mesmo timeout curto derrubava a conexao remota sem necessidade.
  bool _ehNuvem(String base) => base == cloudBaseUrl;

  Duration _timeoutSonda(String base) =>
      _ehNuvem(base) ? const Duration(seconds: 6) : const Duration(seconds: 2);

  Duration _timeoutGet(String base) =>
      _ehNuvem(base) ? const Duration(seconds: 8) : const Duration(seconds: 3);

  Duration _timeoutPost(String base) =>
      _ehNuvem(base) ? const Duration(seconds: 10) : const Duration(seconds: 4);

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

  // Busca o historico persistido na nuvem/servidor para o periodo. Serve para
  // preencher, no relatorio, os trechos gravados enquanto o app estava fechado
  // (o registro local so acontece com a tela de monitoramento aberta).
  Future<List<Map<String, dynamic>>> buscarHistorico({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final ini = inicio.millisecondsSinceEpoch;
    final f = fim.millisecondsSinceEpoch;
    final response = await _getComFallback('/historico?inicio=$ini&fim=$f');
    if (response?.statusCode != 200) return const [];

    final dados = _decodificarMapa(response!.body);
    final lista = dados?['leituras'];
    if (lista is! List) return const [];
    return lista.whereType<Map<String, dynamic>>().toList();
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
      // A conexao esta boa: aproveita para drenar comandos pendentes antigos.
      // So quando for um comando direto do usuario, para nao recursar quando o
      // proprio drenador chama este metodo (enfileirarSeOffline: false).
      if (enfileirarSeOffline) {
        unawaited(sincronizarComandosPendentes());
      }
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
    String nomeDaBase(String base) {
      if (base == localBaseUrl) return 'Local';
      if (base == localPort80FallbackUrl) return 'Local (porta 80, ESP32)';
      return 'Nuvem';
    }

    final candidatas = _candidatas();
    final resultados = await Future.wait(
      candidatas.map((base) async => MapEntry(base, await _estaOnline(base))),
    );

    return [
      for (final resultado in resultados)
        ApiConnectionProbe(
          baseUrl: resultado.key,
          nome: nomeDaBase(resultado.key),
          online: resultado.value,
        ),
    ];
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
          .timeout(_timeoutGet(ativa));
    } catch (_) {
      _baseUrlAtiva = null;
      final fallback = await _resolverBaseAtiva(force: true);
      if (fallback == null) return null;

      try {
        return await http
            .get(Uri.parse('$fallback$path'), headers: _headers())
            .timeout(_timeoutGet(fallback));
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
          .timeout(_timeoutPost(ativa));
    } catch (_) {
      _baseUrlAtiva = null;
      final fallback = await _resolverBaseAtiva(force: true);
      if (fallback == null) return null;

      try {
        return await http
            .post(Uri.parse('$fallback$path'), headers: headers, body: body)
            .timeout(_timeoutPost(fallback));
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

    // Sonda todas as candidatas em paralelo: o tempo total vira o da mais
    // lenta, em vez da soma dos timeouts (local morto + porta 80 + nuvem).
    final candidatas = _candidatas();
    final respostas = await Future.wait(
      candidatas.map((base) async => MapEntry(base, await _estaOnline(base))),
    );
    final online = {
      for (final resposta in respostas) resposta.key: resposta.value,
    };

    // Prioridade: local primeiro; nuvem so quando o local nao responde.
    String? escolhida;
    for (final base in candidatas) {
      if (online[base] == true) {
        escolhida = base;
        break;
      }
    }

    _baseUrlAtiva = escolhida;
    _ultimaResolucao = agora;
    if (escolhida != null) {
      _ultimaConexaoBoa[localBaseUrl] = _ResolucaoConexao(escolhida, agora);
    }
    return escolhida;
  }

  Future<bool> _estaOnline(String base) async {
    final timeout = _timeoutSonda(base);
    try {
      final response = await http
          .get(Uri.parse('$base/status'), headers: _headers())
          .timeout(timeout);
      if (response.statusCode == 200) return true;
    } catch (_) {
      // Alguns prototipos ESP32 respondem o JSON diretamente na rota raiz.
    }

    try {
      final response = await http
          .get(Uri.parse('$base/'), headers: _headers())
          .timeout(timeout);
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

class _ResolucaoConexao {
  final String base;
  final DateTime quando;

  const _ResolucaoConexao(this.base, this.quando);
}
