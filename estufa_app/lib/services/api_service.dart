import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/notificacoes/services/push_notification_service.dart';
import 'isar_service.dart';

enum ApiCommandFailure {
  none,
  offline,
  unauthorized,
  invalidRequest,
  serverError,
}

/// Como terminou a tentativa de subir a chave da estufa para a nuvem.
enum ResultadoChaveNuvem {
  registrada,
  /// A nuvem tem outra chave para este aparelho: a do app esta velha.
  chaveDivergente,
  /// Nem a chave do app nem a global foram aceitas.
  naoAutorizado,
  semNuvem,
  semIdHardware,
  semChave,
  falhou,
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
  /// Base montada a partir do IP que o aparelho reportou, quando conhecido.
  String? _enderecoReportado;
  // Uma sonda local que falha nao derruba a conexao local. A resolucao do nome
  // mDNS falha sozinha de vez em quando, e cada falha isolada trocava a FONTE
  // dos numeros na tela: o cartao piscava entre LOCAL e NUVEM em questao de
  // segundos, mostrando alternadamente o aparelho e a nuvem - com valores
  // diferentes, porque a nuvem tem o atraso do ultimo envio. Duas falhas
  // seguidas ja significam que o aparelho saiu do alcance de verdade.
  static const int _falhasLocaisParaDesistir = 2;
  int _falhasLocaisSeguidas = 0;
  DateTime _ultimaResolucao = DateTime.fromMillisecondsSinceEpoch(0);
  ApiCommandFailure _ultimaFalhaComando = ApiCommandFailure.none;
  ResultadoAlcance? _ultimoAlcance;

  /// Quem fala HTTP. Existe como campo, e nao como `http.get` solto, para o
  /// teste poder responder no lugar da rede.
  ///
  /// Sem isto nenhuma requisicao desta classe podia ser afirmada em teste — e
  /// foi assim que a sonda de alcance passou meses pedindo `/status` sem o
  /// `idHardware`, dizendo "Nuvem: offline" com a leitura da nuvem na tela. Um
  /// teste de tres linhas teria pego; nao havia por onde escrever esse teste.
  final http.Client _cliente;

  ApiService(
    String ip, {
    String? cloudUrl,
    String? token,
    this.idHardware,
    http.Client? cliente,
  }) : _cliente = cliente ?? http.Client(),
       ipOriginal = ip,
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

  // Nome mDNS (`sentinela-xxxxxx.local`) precisa ser RESOLVIDO antes de a
  // requisicao sair, e no Android a primeira resolucao depois de o celular
  // acordar ou entrar na rede passa de 2 s com alguma frequencia. Com o timeout
  // curto a sonda local falhava, o app caia na nuvem e so voltava ao local na
  // resolucao seguinte - de forma intermitente, que e o pior jeito de falhar.
  // Endereco por IP nao paga esse pedagio e continua com o prazo curto.
  static bool _ehNomeMdns(String base) => base.contains('.local');

  Duration _timeoutSonda(String base) {
    if (_ehNuvem(base)) return const Duration(seconds: 6);
    return _ehNomeMdns(base)
        ? const Duration(seconds: 4)
        : const Duration(seconds: 2);
  }

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
      _capturarIpReportado(dados);
      if (!_capturarIdHardwareLocal(dados)) {
        // Aparelho errado no endereco desta estufa: melhor ficar sem leitura do
        // que mostrar a de outra estufa como se fosse desta.
        _abandonarConexaoLocal();
        return null;
      }
      final pendenciasSincronizadas = await sincronizarComandosPendentes();

      if (pendenciasSincronizadas > 0) {
        final responseAtualizada = await _getComFallback(caminhoStatus);
        if (responseAtualizada?.statusCode == 200) {
          return _decodificarMapa(responseAtualizada!.body);
        }
      }

      return dados;
    }

    // Sem recuo para a rota raiz: existiu um adaptador do formato antigo, mas
    // ele traduzia alarme de temperatura e falha de sensor como INCENDIO - o
    // alerta critico, nao silenciavel, que hoje toca sirene no celular. Como
    // todo aparelho em campo serve /status, era um falso alarme guardado a
    // espera de uma condicao rara. Se a leitura falhou, e melhor dizer que
    // falhou.
    return null;
  }

  // Na conexao local (lendo o ESP direto), guarda o idHardware do aparelho para
  // as leituras remotas puxarem o estado dele na nuvem. So captura em LOCAL: no
  // modo nuvem o id vem do proprio parametro enviado.
  //
  // Devolve false quando quem atendeu NAO e o aparelho desta estufa. Um endereco
  // nao identifica um aparelho: o IP muda por DHCP e redes diferentes reusam a
  // mesma faixa, entao o endereco guardado de uma estufa pode, mais tarde,
  // pertencer a outro ESP - inclusive ao de outra estufa do proprio app. Foi o
  // que aconteceu em campo: um aparelho desligado na casa do primo, o endereco
  // dele reaproveitado na rede daqui, e a estufa dele passou a exibir os dados
  // da estufa daqui. Aprender o id so vale enquanto ela ainda nao tem um.
  bool _capturarIdHardwareLocal(Map<String, dynamic> dados) {
    if (modoConexao != 'LOCAL') return true;
    final status = dados['status'];
    final idLido = status is Map ? status['idHardware'] : null;
    if (idLido is! String || idLido.isEmpty) return true;

    final atual = idHardware;
    if (atual != null && atual.isNotEmpty) {
      // Trocar o ESP de uma estufa e possivel, mas pela reconfiguracao, que e um
      // ato deliberado. Silenciosamente, nunca: dar os numeros de um aparelho
      // como se fossem de outro e pior do que nao mostrar numero nenhum.
      return idLido == atual;
    }

    idHardware = idLido;
    unawaited(
      IsarService.instance
          .definirIdHardwarePorIp(ipOriginal, idLido)
          .then((_) => PushNotificationService.instance.sincronizarEstufas()),
    );
    return true;
  }

  /// Guarda o endereco que o aparelho reporta, de qualquer caminho: lido pela
  /// nuvem, ele serve para alcancar o aparelho na rede local depois. Um IP de
  /// outra faixa (o do ponto de acesso, por exemplo) nao ajuda e e ignorado.
  void _capturarIpReportado(Map<String, dynamic> dados) {
    final status = dados['status'];
    final ip = status is Map ? status['ipLocal'] : null;
    if (ip is! String || ip.isEmpty || ip == '0.0.0.0') return;
    final base = _normalizarBaseUrl(ip);
    if (base.isEmpty || base == localBaseUrl) return;
    if (_enderecoReportado == base) return;
    _enderecoReportado = base;
    final id = idHardware;
    if (id != null && id.isNotEmpty) unawaited(_guardarIpReportado(id, ip));
  }

  static const String _prefixoIpReportado = 'ip_reportado_';

  Future<void> _guardarIpReportado(String idHardware, String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefixoIpReportado$idHardware', ip);
    } catch (_) {
      // Melhor esforco: sem isso o endereco vale so nesta sessao.
    }
  }

  /// Recupera o endereco aprendido em sessoes anteriores. Chamado no inicio do
  /// app: e justamente quando nao ha nuvem nem nome resolvendo que ele importa,
  /// e ai nao houve leitura nenhuma nesta sessao para ensina-lo.
  Future<void> carregarIpReportado() async {
    final id = idHardware;
    if (id == null || id.isEmpty || _enderecoReportado != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('$_prefixoIpReportado$id');
      if (ip == null || ip.isEmpty) return;
      final base = _normalizarBaseUrl(ip);
      if (base.isNotEmpty && base != localBaseUrl) _enderecoReportado = base;
    } catch (_) {
      // Segue sem a segunda porta.
    }
  }

  // Descarta a conexao local em curso e a lembranca compartilhada dela. Usado
  // quando o aparelho que atendeu no endereco nao e o desta estufa.
  void _abandonarConexaoLocal() {
    _ultimaConexaoBoa.remove(localBaseUrl);
    _baseUrlAtiva = null;
    _ultimaResolucao = DateTime.fromMillisecondsSinceEpoch(0);
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

  /// Repassa para a nuvem uma leitura obtida na rede LOCAL ("ponte").
  ///
  /// Existe por causa de um falso alarme real: com energia na propriedade mas
  /// sem internet la, o aparelho nao consegue postar, e o watchdog da nuvem -
  /// que so ve ausencia - avisa "sem comunicacao" mesmo com a estufa
  /// funcionando e o app mostrando tudo certo em LOCAL. Se o celular tem
  /// internet propria (4G), ele e a unica ponte disponivel: repassando a
  /// leitura, o `ultimoContatoMs` do servidor fica fresco e o alarme falso nao
  /// chega a nascer. De brinde, quem acompanha de longe volta a ver os dados.
  ///
  /// So faz sentido quando a leitura veio do proprio aparelho (modo LOCAL); em
  /// modo nuvem a leitura JA veio de la. Silencioso de proposito: e um esforco
  /// oportunista, e falhar nao pode atrapalhar a tela.
  Future<bool> repassarLeituraParaNuvem(Map<String, dynamic> dados) async {
    final nuvem = cloudBaseUrl;
    final id = idHardware;
    if (nuvem == null ||
        nuvem.isEmpty ||
        id == null ||
        id.isEmpty ||
        modoConexao != 'LOCAL') {
      return false;
    }

    final status = dados['status'];
    if (status is! Map) return false;

    // `fonte` marca que veio pela ponte, nao direto do hardware: o servidor
    // guarda como telemetria normal, mas a origem fica registrada.
    final payload = <String, dynamic>{
      ...Map<String, dynamic>.from(status),
      'idHardware': id,
      'fonte': 'ponte_app',
      if (dados['config'] != null) 'config': dados['config'],
    };

    try {
      final resposta = await _cliente
          .post(
            Uri.parse('$nuvem/leitura'),
            headers: _headers({'Content-Type': 'application/json'}),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      return _respostaSucesso(resposta.statusCode);
    } catch (_) {
      // Sem internet no celular tambem: nada a fazer, e esperado.
      return false;
    }
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
      return await _cliente
          .get(Uri.parse('$ativa$path'), headers: _headers())
          .timeout(_timeoutGet(ativa));
    } catch (_) {
      _baseUrlAtiva = null;
      final fallback = await _resolverBaseAtiva(force: true);
      if (fallback == null) return null;

      try {
        return await _cliente
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
      return await _cliente
          .post(Uri.parse('$ativa$path'), headers: headers, body: body)
          .timeout(_timeoutPost(ativa));
    } catch (_) {
      _baseUrlAtiva = null;
      final fallback = await _resolverBaseAtiva(force: true);
      if (fallback == null) return null;

      try {
        return await _cliente
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

    if (escolhida != null) {
      _falhasLocaisSeguidas = 0;
    } else if (locais.isNotEmpty) {
      _falhasLocaisSeguidas++;
      final ativa = _baseUrlAtiva;
      if (_falhasLocaisSeguidas < _falhasLocaisParaDesistir &&
          ativa != null &&
          !_ehNuvem(ativa)) {
        // Segura a local ja estabelecida. Se ela tiver caido mesmo, a chamada
        // real falha em seguida e a re-resolucao forcada completa a segunda
        // falha - o custo e uma requisicao perdida, nao a troca da fonte.
        _ultimaResolucao = agora;
        return ativa;
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

  // Status 200 nao basta para dizer que o aparelho respondeu. O endereco pode ter
  // passado para outro dispositivo qualquer da rede - impressora, camera,
  // roteador -, e qualquer um deles devolve 200 com HTML na porta 80. O app
  // entao concluia "a estufa esta na rede local" e ficava preso ali: sem dado,
  // porque o HTML nao decodifica, e sem cair para a nuvem, porque a sonda
  // insistia que estava tudo bem. A resposta tem que se PARECER com a de um
  // Sentinela.
  bool _pareceSentinela(String corpo) {
    final mapa = _decodificarMapa(corpo);
    return mapa != null && mapa['status'] is Map;
  }

  Future<bool> _estaOnline(String base) async {
    final timeout = _timeoutSonda(base);
    // Mesmo caminho da leitura de verdade, inclusive o `idHardware`. A sonda
    // pedia `/status` pelado, e na nuvem isso e outra requisicao: sem o id o
    // servidor nao sabe de qual aparelho se fala, e a isencao do simulador -
    // que e por id - nao vale. O resultado era o pior tipo de contradicao:
    // o cartao dizendo "Reportando (via nuvem)", com numeros na tela, e o teste
    // de alcance logo abaixo dizendo "Nuvem: offline". Um dos dois estava
    // mentindo, e era este.
    final id = idHardware;
    final caminho = id == null || id.isEmpty
        ? '/status'
        : '/status?idHardware=${Uri.encodeComponent(id)}';
    try {
      final response = await _cliente
          .get(Uri.parse('$base$caminho'), headers: _headers())
          .timeout(timeout);
      if (response.statusCode == 200 && _pareceSentinela(response.body)) {
        return true;
      }
    } catch (_) {
      // Alguns prototipos ESP32 respondem o JSON diretamente na rota raiz.
    }

    try {
      final response = await _cliente
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

  List<String> _candidatas() {
    final lista = <String>[localBaseUrl];
    if (localPort80FallbackUrl != null &&
        localPort80FallbackUrl != localBaseUrl) {
      lista.add(localPort80FallbackUrl!);
    }
    // Endereco que o proprio aparelho reportou. Segunda porta local: o nome mDNS
    // nao resolve em parte dos celulares e roteadores, e ate aqui, quando ele
    // falhava, nao sobrava caminho nenhum - a nuvem funcionando escondia isso.
    // Vem depois do nome de proposito: o nome sobrevive a troca de IP, o IP nao.
    final reportado = _enderecoReportado;
    if (reportado != null && !lista.contains(reportado)) {
      lista.add(reportado);
    }
    if (cloudBaseUrl != null &&
        cloudBaseUrl != localBaseUrl &&
        cloudBaseUrl != localPort80FallbackUrl) {
      lista.add(cloudBaseUrl!);
    }
    return lista;
  }

  /// O aparelho se anuncia como `sentinela-xxxxxx.local`, mas se apresenta em
  /// `/dados` sem o sufixo. Um nome sem `.local` nao e nome mDNS: o sistema
  /// tenta DNS comum, que nao responde por ele em rede domestica nenhuma - a
  /// conexao local simplesmente nunca acontecia, e a nuvem funcionando escondia
  /// isso. Completar aqui conserta tambem as estufas ja cadastradas sem ele,
  /// sem o produtor ter de editar nada.
  static String completarNomeMdns(String enderecoOuNome) {
    final valor = enderecoOuNome.trim();
    if (!valor.toLowerCase().startsWith('sentinela-')) return valor;
    if (valor.contains('.')) return valor;
    final separador = RegExp(r'[:/]').firstMatch(valor);
    if (separador == null) return '$valor.local';
    final inicio = separador.start;
    return '${valor.substring(0, inicio)}.local${valor.substring(inicio)}';
  }

  static String _normalizarBaseUrl(String ipOuUrl) {
    final valor = completarNomeMdns(ipOuUrl);
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
    final valor = completarNomeMdns(ipOuUrl);
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

  /// Sobe a chave desta estufa para a nuvem, para ela poder autorizar comandos
  /// deste aparelho sem depender da chave global.
  ///
  /// O produtor le a chave no modo de configuracao - presenca fisica na frente do
  /// aparelho - e e esse ato que ancora a confianca. O app so faz o transporte.
  /// O aparelho tambem registra a propria chave por conta dele; os dois caminhos
  /// convergem no mesmo TOFU e o primeiro que chegar resolve.
  ///
  /// Vai SEMPRE na nuvem, nunca no endereco local: a rota e do servidor, e o ESP
  /// nao a serve. Melhor esforco - falhar aqui nao pode atrapalhar o cadastro,
  /// que e o que o produtor esta fazendo.
  /// [chaveNova] registra uma chave DIFERENTE da que autentica esta chamada.
  ///
  /// A distincao e o que faz trocar de chave funcionar. Uma chave recem-inventada
  /// nao autentica em nada - foi assim que trocar a chave do simulador o deixou
  /// offline: o app mandava a chave nova como credencial E como conteudo, e a
  /// nuvem recusava as duas pontas. Quem autentica e sempre a credencial que a
  /// nuvem JA aceita (a atual do app); a nova viaja no corpo.
  Future<ResultadoChaveNuvem> registrarChaveNaNuvem({String? chaveNova}) async {
    final base = cloudBaseUrl;
    final id = idHardware;
    final credencial = authToken;
    if (base == null || base.isEmpty) return ResultadoChaveNuvem.semNuvem;
    if (id == null || id.isEmpty) return ResultadoChaveNuvem.semIdHardware;
    if (credencial == null || credencial.isEmpty) {
      return ResultadoChaveNuvem.semChave;
    }
    final alvo = (chaveNova != null && chaveNova.isNotEmpty)
        ? chaveNova
        : credencial;

    final resultado = await _postChave('$base/aparelhos/chave', {
      'idHardware': id,
      'chave': alvo,
    });
    // 409 = a nuvem guarda outra chave para este aparelho. Se estamos propondo
    // uma troca, o caminho certo e a rotacao, que prova posse da anterior.
    if (resultado == ResultadoChaveNuvem.chaveDivergente && alvo != credencial) {
      return _postChave('$base/aparelhos/chave/rotacionar', {
        'idHardware': id,
        'chaveAtual': credencial,
        'chaveNova': alvo,
      });
    }
    return resultado;
  }

  Future<ResultadoChaveNuvem> _postChave(
    String url,
    Map<String, String> corpo,
  ) async {
    try {
      final resposta = await _cliente
          .post(
            Uri.parse(url),
            headers: _headers({'Content-Type': 'application/json'}),
            body: jsonEncode(corpo),
          )
          .timeout(const Duration(seconds: 15));
      if (resposta.statusCode == 200) return ResultadoChaveNuvem.registrada;
      if (resposta.statusCode == 409) return ResultadoChaveNuvem.chaveDivergente;
      // 403 na rotacao: a nuvem tem uma terceira chave, que nem o app conhece.
      if (resposta.statusCode == 403) return ResultadoChaveNuvem.chaveDivergente;
      if (resposta.statusCode == 401) return ResultadoChaveNuvem.naoAutorizado;
      return ResultadoChaveNuvem.falhou;
    } catch (_) {
      return ResultadoChaveNuvem.falhou;
    }
  }

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
