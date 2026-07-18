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

  final String ipOriginal;
  final String localBaseUrl;
  final String? localPort80FallbackUrl;
  final String? cloudBaseUrl;
  final String? authToken;
  // Identificador do aparelho na nuvem. Enviado no /status remoto para puxar o
  // estado do aparelho certo; capturado na 1a conexao local (do /status do ESP).
  String? idHardware;

  String? _baseUrlAtiva;
  DateTime _ultimaResolucao = DateTime.fromMillisecondsSinceEpoch(0);
  ApiCommandFailure _ultimaFalhaComando = ApiCommandFailure.none;
  ResultadoAlcance? _ultimoAlcance;

  ApiService(String ip, {String? cloudUrl, String? token, this.idHardware})
    : ipOriginal = ip,
      localBaseUrl = _normalizarBaseUrl(ip),
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

  // A nuvem no plano gratuito hiberna e leva um tempo para responder a primeira
  // chamada depois de ociosa; um timeout curto derrubava a leitura remota justo
  // quando ela estava acordando.
  Duration _timeoutGet(String base) =>
      _ehNuvem(base) ? const Duration(seconds: 15) : const Duration(seconds: 3);

  Duration _timeoutPost(String base) =>
      _ehNuvem(base) ? const Duration(seconds: 15) : const Duration(seconds: 4);

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
    final base = await _resolverBaseAtiva();
    if (base == null) return null;

    final semIdHardware = idHardware == null || idHardware!.isEmpty;
    // Na nuvem, /status sem idHardware devolve o aparelho padrao (hoje, o
    // simulador). Mostrar a leitura de outro aparelho como se fosse desta
    // estufa e pior do que nao mostrar nada: o id e capturado na 1a conexao
    // local, entao ate la esta estufa fica sem dado remoto.
    if (_ehNuvem(base) && semIdHardware) return null;

    final caminhoStatus = semIdHardware
        ? '/status'
        : '/status?idHardware=${Uri.encodeComponent(idHardware!)}';
    final response = await _getComFallback(caminhoStatus);
    if (response?.statusCode == 200) {
      final dados = _decodificarMapa(response!.body);
      if (dados == null) return null;
      _capturarIdHardwareLocal(dados);
      final pendenciasSincronizadas = await sincronizarComandosPendentes();

      if (pendenciasSincronizadas > 0) {
        final responseAtualizada = await _getComFallback(caminhoStatus);
        if (responseAtualizada?.statusCode == 200) {
          return _decodificarMapa(responseAtualizada!.body);
        }
      }

      return dados;
    }

    // A rota raiz e o formato antigo servido pelo proprio ESP na rede local.
    // Na nuvem ela nao vale: alem de nao ser por aparelho, o adaptador carimba
    // o timestamp com a hora atual, o que esconderia o "sem sinal".
    if (modoConexao == 'NUVEM') return null;

    final responseRaiz = await _getComFallback('/');
    if (responseRaiz?.statusCode == 200) {
      final dadosRaiz = _decodificarMapa(responseRaiz!.body);
      if (dadosRaiz == null) return null;
      return _adaptarStatusRaizEsp32(dadosRaiz);
    }

    return null;
  }

  // Na conexao local (lendo o ESP direto), guarda o idHardware do aparelho para
  // as leituras remotas puxarem o estado dele na nuvem. So captura em LOCAL: no
  // modo nuvem o id vem do proprio parametro enviado.
  void _capturarIdHardwareLocal(Map<String, dynamic> dados) {
    if (modoConexao != 'LOCAL') return;
    final status = dados['status'];
    final idLido = status is Map ? status['idHardware'] : null;
    if (idLido is String && idLido.isNotEmpty && idLido != idHardware) {
      idHardware = idLido;
      unawaited(IsarService.instance.definirIdHardwarePorIp(ipOriginal, idLido));
    }
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
    // Na nuvem o comando precisa dizer a quem se destina: o servidor guarda na
    // caixa daquele aparelho, que vem busca-lo. Na rede local e dispensavel (o
    // destino e o proprio aparelho que responde), mas mandar sempre mantem um
    // payload so e permite que a fila de pendencias seja drenada por qualquer
    // um dos dois caminhos.
    final payload = idHardware != null && idHardware!.isNotEmpty
        ? {...dadosParaAtualizar, 'idHardware': idHardware}
        : dadosParaAtualizar;

    final response = await _postComFallback(
      '/sincronizar',
      headers: _headers({'Content-Type': 'application/json'}),
      body: jsonEncode(payload),
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

  /// Resultado do ultimo teste de alcance, com o instante em que foi feito.
  /// Nulo enquanto ninguem tiver testado nesta estufa.
  ResultadoAlcance? get ultimoAlcance => _ultimoAlcance;

  /// Sonda os enderecos. Como o ApiService e compartilhado pelas telas, o
  /// resultado sobrevive a fechar e reabrir o dialogo: sem [forcar], reabrir
  /// mostra na hora o que ja se sabe, em vez de sondar tudo de novo (a sonda da
  /// nuvem sozinha pode levar mais de 10 s).
  Future<List<ApiConnectionProbe>> verificarConexoes({
    bool forcar = false,
    Duration validade = const Duration(minutes: 2),
  }) async {
    final anterior = _ultimoAlcance;
    if (!forcar &&
        anterior != null &&
        DateTime.now().difference(anterior.quando) < validade) {
      return anterior.probes;
    }

    final probes = await _sondarConexoes();
    _ultimoAlcance = ResultadoAlcance(probes: probes, quando: DateTime.now());
    return probes;
  }

  Future<List<ApiConnectionProbe>> _sondarConexoes() async {
    final candidatas = _candidatas();
    final resultados = await Future.wait(
      candidatas.map((base) async => MapEntry(base, await _estaOnline(base))),
    );
    final online = {
      for (final resultado in resultados) resultado.key: resultado.value,
    };

    // As candidatas locais sao o mesmo aparelho em portas diferentes (3000 do
    // servidor, 80 do ESP32). Viram uma linha so: o que interessa e se o
    // aparelho responde na rede local, nao em qual porta ele escuta.
    final locais = candidatas.where((base) => !_ehNuvem(base)).toList();
    String? localQueRespondeu;
    for (final base in locais) {
      if (online[base] == true) {
        localQueRespondeu = base;
        break;
      }
    }

    return [
      if (locais.isNotEmpty)
        ApiConnectionProbe(
          // A porta que respondeu fica no baseUrl, fora do rotulo: para quem
          // usa, o que importa e se a estufa responde na rede local.
          baseUrl: localQueRespondeu ?? localBaseUrl,
          nome: 'Local',
          online: localQueRespondeu != null,
        ),
      for (final base in candidatas.where(_ehNuvem))
        ApiConnectionProbe(
          baseUrl: base,
          nome: 'Nuvem',
          online: online[base] == true,
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

    final candidatas = _candidatas();
    final locais = candidatas.where((base) => !_ehNuvem(base)).toList();

    // Sonda so as candidatas locais, em paralelo: sao rapidas e o tempo total
    // vira o da mais lenta, em vez da soma dos timeouts.
    String? escolhida;
    if (locais.isNotEmpty) {
      final respostas = await Future.wait(
        locais.map((base) async => MapEntry(base, await _estaOnline(base))),
      );
      final online = {
        for (final resposta in respostas) resposta.key: resposta.value,
      };
      // Prioridade: local primeiro; nuvem so quando o local nao responde.
      for (final base in locais) {
        if (online[base] == true) {
          escolhida = base;
          break;
        }
      }
    }

    // A nuvem nao e sondada: a sonda e o mesmo GET /status da leitura, entao
    // sondar dobrava as chamadas remotas. Se a chamada real falhar,
    // _getComFallback ja re-resolve a conexao.
    if (escolhida == null) {
      for (final base in candidatas) {
        if (_ehNuvem(base)) {
          escolhida = base;
          break;
        }
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

/// Um teste de alcance com a hora em que foi feito - a hora importa tanto
/// quanto o resultado, porque o que se ve pode nao ser mais verdade.
class ResultadoAlcance {
  final List<ApiConnectionProbe> probes;
  final DateTime quando;

  const ResultadoAlcance({required this.probes, required this.quando});
}

class _ResolucaoConexao {
  final String base;
  final DateTime quando;

  const _ResolucaoConexao(this.base, this.quando);
}
