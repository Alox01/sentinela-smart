import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api_service.dart';

/// Uma leitura ja resolvida, do jeito que as telas precisam consumir.
///
/// [dados] nulo significa que a busca falhou (o app nao alcancou nem o aparelho
/// nem a nuvem). [recebidaEmMs] identifica a leitura: quem processa efeitos
/// colaterais usa isso para nao repetir o trabalho na mesma leitura.
@immutable
class LeituraAoVivo {
  final Map<String, dynamic>? dados;
  final String modoConexao;
  final int recebidaEmMs;

  const LeituraAoVivo({
    required this.dados,
    required this.modoConexao,
    required this.recebidaEmMs,
  });

  bool get temDados => dados != null;
}

/// Fonte unica da leitura ao vivo de uma estufa.
///
/// Antes, a tela dos galpoes e a de monitoramento buscavam cada uma por conta
/// propria: abrir uma estufa recomecava do zero (ate ~15s pela nuvem) mesmo com
/// o card tendo acabado de ler, e os dois timers corriam em paralelo. Aqui a
/// busca acontece uma vez so e todo mundo observa o resultado.
///
/// O polling seque a contagem de assinantes: comeca quando o primeiro assina e
/// para quando o ultimo sai. Assim os cards param sozinhos quando a home fica
/// coberta, sem as telas precisarem coordenar nada entre si.
class EstufaMonitor extends ChangeNotifier {
  static const Duration intervaloPadrao = Duration(seconds: 3);

  final ApiService api;
  final Duration intervalo;
  final Future<Map<String, dynamic>?> Function() _buscar;

  LeituraAoVivo? _ultima;
  Timer? _timer;
  int _assinantes = 0;
  bool _buscando = false;
  bool _pausado = false;

  EstufaMonitor({
    required this.api,
    Future<Map<String, dynamic>?> Function()? buscar,
    this.intervalo = intervaloPadrao,
  }) : _buscar = buscar ?? api.buscarStatus;

  /// A ultima leitura conhecida, disponivel na hora em que alguem assina - e o
  /// que faz a tela de monitoramento abrir ja preenchida.
  LeituraAoVivo? get ultima => _ultima;

  bool get ativo => _timer != null;

  void assinar(VoidCallback ouvinte) {
    addListener(ouvinte);
    _assinantes++;
    if (_assinantes == 1) _iniciar();
  }

  void desassinar(VoidCallback ouvinte) {
    removeListener(ouvinte);
    if (_assinantes == 0) return;
    _assinantes--;
    if (_assinantes == 0) _parar();
  }

  /// Busca fora do ritmo do timer. Usado logo apos um comando ser aceito, para
  /// a tela e o card refletirem a mudanca sem esperar o proximo tique.
  Future<void> atualizarAgora() => _atualizar();

  void _iniciar() {
    if (_pausado || _timer != null) return;
    unawaited(_atualizar());
    _timer = Timer.periodic(intervalo, (_) => unawaited(_atualizar()));
  }

  void _parar() {
    _timer?.cancel();
    _timer = null;
  }

  /// Chamado pelo registro quando o app sai da frente: sem assinantes ativos na
  /// tela nao ha motivo para gastar bateria e dados moveis.
  void pausar() {
    _pausado = true;
    _parar();
  }

  void retomar() {
    _pausado = false;
    if (_assinantes > 0) _iniciar();
  }

  Future<void> _atualizar() async {
    // Uma leitura pela nuvem pode demorar mais que o intervalo; sem esta trava
    // as requisicoes se acumulam e as respostas chegam fora de ordem.
    if (_buscando) return;
    _buscando = true;
    Map<String, dynamic>? dados;
    try {
      dados = await _buscar();
    } finally {
      _buscando = false;
    }

    _ultima = LeituraAoVivo(
      dados: dados,
      modoConexao: api.modoConexao,
      recebidaEmMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _parar();
    super.dispose();
  }
}

/// Registro dos monitores vivos, um por estufa.
class MonitorEstufas with WidgetsBindingObserver {
  MonitorEstufas._();

  static final MonitorEstufas instance = MonitorEstufas._();

  final Map<int, _EntradaMonitor> _monitores = {};
  bool _observando = false;

  /// Monitor da estufa, criado sob demanda. A chave e o id do Isar, nao o
  /// endereco: o produtor pode editar o IP da estufa sem que ela vire outra.
  EstufaMonitor obter({
    required int idEstufa,
    required String ip,
    String? token,
    String? idHardware,
  }) {
    _garantirObservador();

    final existente = _monitores[idEstufa];
    if (existente != null) {
      if (existente.combina(ip: ip, token: token, idHardware: idHardware)) {
        return existente.monitor;
      }
      // Endereco, chave ou id do aparelho mudaram: o ApiService antigo aponta
      // para o lugar errado. Pausa em vez de descartar - alguma tela ainda pode
      // estar segurando esta instancia, e chamar removeListener num
      // ChangeNotifier ja descartado quebra em modo debug.
      existente.monitor.pausar();
      _monitores.remove(idEstufa);
    }

    final monitor = EstufaMonitor(
      api: ApiService(ip, token: token, idHardware: idHardware),
    );
    _monitores[idEstufa] = _EntradaMonitor(
      monitor: monitor,
      ip: ip,
      token: token,
      idHardware: idHardware,
    );
    return monitor;
  }

  void _garantirObservador() {
    if (_observando) return;
    // Em teste nao ha binding inicializado; o registro segue util sem o
    // controle de ciclo de vida.
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _observando = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final emPrimeiroPlano = state == AppLifecycleState.resumed;
    for (final entrada in _monitores.values) {
      if (emPrimeiroPlano) {
        entrada.monitor.retomar();
      } else {
        entrada.monitor.pausar();
      }
    }
  }

  /// Solta o monitor de uma estufa que saiu da lista.
  void remover(int idEstufa) {
    _monitores.remove(idEstufa)?.monitor.pausar();
  }
}

class _EntradaMonitor {
  final EstufaMonitor monitor;
  final String ip;
  final String? token;
  final String? idHardware;

  const _EntradaMonitor({
    required this.monitor,
    required this.ip,
    required this.token,
    required this.idHardware,
  });

  bool combina({
    required String ip,
    required String? token,
    required String? idHardware,
  }) =>
      this.ip == ip &&
      this.token == token &&
      // O id capturado automaticamente preenche um campo antes vazio; isso nao
      // e uma troca de aparelho, entao nao justifica recriar o ApiService (que
      // ja atualizou o proprio idHardware por dentro).
      (this.idHardware == idHardware || this.idHardware == null);
}
