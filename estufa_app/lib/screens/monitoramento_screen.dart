import 'dart:async';
import 'package:flutter/material.dart';

import '../features/monitoramento/dialogs/detalhes_conexao_dialog.dart';
import '../features/monitoramento/dialogs/monitoramento_confirm_dialogs.dart';
import '../features/monitoramento/services/detector_oscilacao.dart';
import '../features/monitoramento/services/monitoramento_repository.dart';
import '../features/monitoramento/services/rastreador_conexao.dart';
import '../features/monitoramento/widgets/alerta_monitoramento_banner.dart';
import '../features/monitoramento/widgets/estufada_atual_card.dart';
import '../features/monitoramento/widgets/leitura_aparelho_card.dart';
import '../features/monitoramento/widgets/monitoramento_app_bar.dart';
import '../features/agendamento/screens/agendamentos_screen.dart';
import '../features/aparelho/screens/configurar_aparelho_screen.dart';
import '../features/notificacoes/models/preferencias_notificacao.dart';
import '../features/notificacoes/services/preferencias_notificacao_service.dart';
import '../features/notificacoes/services/push_notification_service.dart';
import '../features/notificacoes/services/silenciamento_estufas.dart';
import '../models/ciclo_secagem_entity.dart';
import '../services/api_service.dart';
import '../services/isar_service.dart';
import '../services/monitor_estufas.dart';
import '../widgets/painel_controle.dart';
import 'historico_screen.dart';
import '../features/relatorio_estufada/screens/gerenciar_estufadas_screen.dart';

class MonitoramentoScreen extends StatefulWidget {
  // Identifica a estufa no registro de monitores, para esta tela e o card da
  // home compartilharem a mesma leitura ao vivo.
  final int idEstufa;
  final String nomeEstufa;
  final String ipEstufa;
  final String? tokenAcesso;
  final String? idHardware;

  const MonitoramentoScreen({
    super.key,
    required this.idEstufa,
    required this.nomeEstufa,
    required this.ipEstufa,
    this.tokenAcesso,
    this.idHardware,
  });

  @override
  State<MonitoramentoScreen> createState() => _MonitoramentoScreenState();
}

// Sem WidgetsBindingObserver: o ciclo de vida do app e tratado no
// MonitorEstufas, que pausa todos os monitores de uma vez. Esta tela nao
// gerencia mais o proprio polling.
class _MonitoramentoScreenState extends State<MonitoramentoScreen> {
  static const int _intervaloRegistroHistoricoMs = 10 * 60 * 1000;
  // Intervalo minimo entre um registro periodico e um registro disparado por
  // evento (mudanca de ajuste, alarme, desvio). Evita marcar pontos redundantes
  // colados no grafico quando varios eventos acontecem em sequencia.
  static const int _cooldownEventoMs = 3 * 60 * 1000;
  // Valores iniciais de uma nova estufada (inicio da amarelacao). Ajustaveis.
  static const double _tempNovaEstufada = 90.0;
  static const double _umidNovaEstufada = 100.0;

  double temperatura = 0.0;
  String avisoEmergencia = '';
  double umidade = 0.0;
  double tempAjuste = 0.0;
  double umidAjuste = 0.0;
  double? _tempAjustePendente;
  double? _umidAjustePendente;

  bool isFire = false;
  bool sireneLigada = false;
  // Silenciamento pedido e ainda nao confirmado pelo aparelho. Mesma ideia dos
  // ajustes pendentes: o botao responde na hora e a leitura seguinte confirma.
  bool _silencioPendente = false;
  // Veredito do proprio aparelho sobre a temperatura (o app nao emite um
  // segundo parecer: a borda e a fonte da verdade). 'orange' alta, 'purple'
  // baixa, 'green' ok, 'red' fogo.
  String _corStatusAparelho = 'green';
  int _pendenciasSincronizacao = 0;
  bool _sincronizandoPendencias = false;
  // Comeca em CONECTANDO: antes da 1a resposta nao da para afirmar que esta
  // offline, e mostrar vermelho na abertura assustava a toa.
  String _modoConexao = 'CONECTANDO';
  // Identifica a ultima leitura ja processada, para os efeitos colaterais nao
  // rodarem duas vezes sobre a mesma.
  int? _ultimaLeituraProcessadaMs;
  int _ultimoRegistroHistoricoMs = 0;
  CicloSecagemEntity? _cicloAtual;
  double? _ultimoTempAjusteServidor;
  double? _ultimoUmidAjusteServidor;
  bool? _ultimoAlertaIncendio;
  // Aparelho "sem comunicacao": no modo nuvem, quando a ultima leitura recebida
  // fica velha demais (o aparelho parou de reportar por falta de luz/internet),
  // o app mostra isso em vez de fingir que esta tudo ao vivo.
  static const int _limiarSemComunicacaoMs = 3 * 60 * 1000;
  bool _semComunicacaoAparelho = false;
  int? _ultimaLeituraMs;
  // Comando aceito pela nuvem mas ainda nao obedecido pelo aparelho. O valor na
  // tela ja e o novo, entao sem este aviso o produtor acha que a estufa mudou.
  bool _aguardandoAparelho = false;
  DetectorOscilacao get _detectorOscilacao => _monitor.detectorOscilacao;
  final RastreadorConexao _rastreadorConexao = RastreadorConexao();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sugestaoFimCicloExibida = false;

  Timer? _debounceTemperatura;
  Timer? _debounceUmidade;
  late EstufaMonitor _monitor;
  ApiService get api => _monitor.api;
  final MonitoramentoRepository _monitoramentoRepository =
      MonitoramentoRepository(IsarService.instance);

  @override
  void initState() {
    super.initState();
    _monitor = MonitorEstufas.instance.obter(
      idEstufa: widget.idEstufa,
      ip: widget.ipEstufa,
      token: widget.tokenAcesso,
      idHardware: widget.idHardware,
    );
    unawaited(_carregarCicloAtual());
    unawaited(_atualizarPendencias());
    // O estado de silenciamento por estufa alimenta o interruptor do menu.
    unawaited(SilenciamentoEstufas.instance.carregar());
    // Assinar ja entrega a ultima leitura do card, entao a tela abre preenchida
    // em vez de esperar a propria busca.
    _monitor.assinar(_aoMudarLeitura);
    _aoMudarLeitura();
  }

  @override
  void dispose() {
    _monitor.desassinar(_aoMudarLeitura);
    _debounceTemperatura?.cancel();
    _debounceUmidade?.cancel();
    super.dispose();
  }

  void _aoMudarLeitura() {
    final leitura = _monitor.ultima;
    if (leitura == null) return;
    // Os efeitos abaixo (historico, eventos do ciclo, oscilacao) valem uma vez
    // por leitura. Sem esta guarda, reentrar na tela ou um rebuild qualquer
    // gravaria pontos repetidos no relatorio.
    if (leitura.recebidaEmMs == _ultimaLeituraProcessadaMs) return;
    _ultimaLeituraProcessadaMs = leitura.recebidaEmMs;
    unawaited(atualizarTela());
  }

  Future<void> atualizarTela() async {
    final dados = _monitor.ultima?.dados;
    if (dados == null) {
      if (mounted) {
        setState(() {
          _modoConexao = 'OFFLINE';
        });
        _registrarQuedaConexaoSeNecessario();
        await _atualizarPendencias();
      }
      return;
    }
    if (!mounted) return;
    _registrarRetornoConexaoSeNecessario();

    final status = dados['status'] ?? {};
    final config = dados['config'] ?? {};

    final fogoDetectado =
        status['perigoChama'] == true || status['riscoIncendio'] == true;
    final novaTemperatura = double.parse(
      (status['temperaturaAtual'] ?? 0).toString(),
    );
    final novaUmidade = double.parse((status['umidadeAtual'] ?? 0).toString());
    final novoTempAjuste = double.parse(
      (config['temperaturaMeta'] ?? 0).toString(),
    );
    final novoUmidAjuste = double.parse(
      (config['umidadeMeta'] ?? 0).toString(),
    );
    final novoAviso = status['aviso'] ?? '';
    final novaSireneLigada =
        status['alarmeAtivo'] ?? status['alertaIncendio'] ?? false;
    final tsLeitura = (status['timestampLeitura'] as num?)?.toInt();
    final aguardandoAparelho = dados['aguardandoAparelho'] == true;
    final ajusteTempAnterior = _ultimoTempAjusteServidor;
    final ajusteUmidAnterior = _ultimoUmidAjusteServidor;
    // Ao detectar uma mudanca de ajuste (feita no app ou no aparelho), abre a
    // janela de acomodacao para nao confundir a leitura "perseguindo" o novo
    // ajuste com uma oscilacao causada pelo clima/fogo.
    final agoraAjusteMs = DateTime.now().millisecondsSinceEpoch;
    if (ajusteTempAnterior != null &&
        (novoTempAjuste - ajusteTempAnterior).abs() > 0.5) {
      _detectorOscilacao.registrarMudancaAjusteTemperatura(
        agoraAjusteMs,
        leitura: novaTemperatura,
        ajusteAnterior: ajusteTempAnterior,
        ajusteNovo: novoTempAjuste,
      );
    }
    if (ajusteUmidAnterior != null &&
        (novoUmidAjuste - ajusteUmidAnterior).abs() > 0.5) {
      _detectorOscilacao.registrarMudancaAjusteUmidade(
        agoraAjusteMs,
        leitura: novaUmidade,
        ajusteAnterior: ajusteUmidAnterior,
        ajusteNovo: novoUmidAjuste,
      );
    }
    final deveSugerirFimCiclo =
        _cicloAtual != null &&
        !_sugestaoFimCicloExibida &&
        ajusteTempAnterior != null &&
        ajusteTempAnterior >= 140 &&
        novoTempAjuste < 100;

    _registrarHistoricoSeNecessario(
      temperaturaAtual: novaTemperatura,
      umidadeAtual: novaUmidade,
      temperaturaAjusteAtual: novoTempAjuste,
      umidadeAjusteAtual: novoUmidAjuste,
      avisoAtual: novoAviso,
      alertaIncendioAtual: novaSireneLigada,
    );
    _processarEventosDoCiclo(
      temperaturaAtual: novaTemperatura,
      umidadeAtual: novaUmidade,
      temperaturaAjusteAtual: novoTempAjuste,
      umidadeAjusteAtual: novoUmidAjuste,
      alertaIncendioAtual: novaSireneLigada,
      riscoIncendioAtual: fogoDetectado,
      avisoAtual: novoAviso,
    );

    setState(() {
      if (_tempAjustePendente != null &&
          _tempAjustePendente == novoTempAjuste) {
        _tempAjustePendente = null;
      }
      if (_umidAjustePendente != null &&
          _umidAjustePendente == novoUmidAjuste) {
        _umidAjustePendente = null;
      }
      // O aparelho confirmou (calou) ou o caso mudou para fogo, que nao se
      // silencia: nos dois a leitura volta a mandar.
      if (_silencioPendente && (!novaSireneLigada || fogoDetectado)) {
        _silencioPendente = false;
      }

      temperatura = novaTemperatura;
      umidade = novaUmidade;
      tempAjuste = _tempAjustePendente ?? novoTempAjuste;
      umidAjuste = _umidAjustePendente ?? novoUmidAjuste;
      avisoEmergencia = novoAviso;
      sireneLigada = _silencioPendente ? false : novaSireneLigada;
      _corStatusAparelho = (status['corStatus'] ?? 'green').toString();
      isFire = fogoDetectado;
      // So considera "sem comunicacao" no modo nuvem: em LOCAL, uma leitura
      // recebida ja significa que o aparelho esta vivo agora.
      _aguardandoAparelho = aguardandoAparelho;
      _ultimaLeituraMs = tsLeitura;
      _semComunicacaoAparelho =
          api.modoConexao == 'NUVEM' &&
          tsLeitura != null &&
          (DateTime.now().millisecondsSinceEpoch - tsLeitura) >
              _limiarSemComunicacaoMs;
      _modoConexao = api.modoConexao;
      _ultimoTempAjusteServidor = novoTempAjuste;
      _ultimoUmidAjusteServidor = novoUmidAjuste;
    });

    if (deveSugerirFimCiclo) {
      _sugestaoFimCicloExibida = true;
      unawaited(_sugerirFinalizacaoPorQuedaAjuste());
    }

    unawaited(_sincronizarPendenciasSeNecessario());
  }

  void _registrarHistoricoSeNecessario({
    required double temperaturaAtual,
    required double umidadeAtual,
    required double temperaturaAjusteAtual,
    required double umidadeAjusteAtual,
    required String avisoAtual,
    required bool alertaIncendioAtual,
    bool forcar = false,
    bool porEvento = false,
  }) {
    if (_cicloAtual == null) return;

    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    // forcar: sempre grava (ex: inicio da estufada). porEvento: grava so se
    // passou o cooldown. Caso normal: grava no intervalo periodico (10 min).
    if (!forcar) {
      final intervaloMinimo = porEvento
          ? _cooldownEventoMs
          : _intervaloRegistroHistoricoMs;
      if ((agoraMs - _ultimoRegistroHistoricoMs) < intervaloMinimo) {
        return;
      }
    }

    _ultimoRegistroHistoricoMs = agoraMs;
    unawaited(
      _monitoramentoRepository.salvarLeitura(
        ipEstufa: widget.ipEstufa,
        nomeEstufa: widget.nomeEstufa,
        temperatura: temperaturaAtual,
        umidade: umidadeAtual,
        temperaturaAjuste: temperaturaAjusteAtual,
        umidadeAjuste: umidadeAjusteAtual,
        aviso: avisoAtual,
        alertaIncendio: alertaIncendioAtual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corFundo = isFire ? const Color(0xFF330000) : const Color(0xFF0E1012);
    final isSuperaquecimentoNaoIntencional =
        temperatura >= 165.0 && temperatura > (tempAjuste + 2.0);
    final agoraLedMs = DateTime.now().millisecondsSinceEpoch;
    final folgaUmid = _detectorOscilacao.folgaUmidade(agoraLedMs);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: corFundo,
      endDrawer: _buildMenuEstufa(),
      appBar: MonitoramentoAppBar(
        nomeEstufa: widget.nomeEstufa,
        // O aparelho parado pesa mais que o meio de leitura: de nada adianta
        // dizer "NUVEM" em azul quando os dados na tela sao antigos.
        modoConexao: _semComunicacaoAparelho ? 'SEM SINAL' : _modoConexao,
        sincronizando: _sincronizandoPendencias,
        pendencias: _pendenciasSincronizacao,
        onAbrirMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onPullRefresh,
          color: Colors.white,
          backgroundColor: const Color(0xFF1C1C1E),
          child: SingleChildScrollView(
            // Sempre rolavel, para o puxar-para-atualizar funcionar mesmo
            // quando o conteudo cabe inteiro na tela.
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isFire || isSuperaquecimentoNaoIntencional)
                    AlertaMonitoramentoBanner(
                      incendioDetectado: isFire,
                      temperaturaAtual: temperatura,
                      avisoEmergencia: avisoEmergencia,
                    ),
                  // Sem banner de falta de energia: o aparelho nao tem sensor de
                  // tensao nem bateria, entao `temEnergia` e sempre true e o
                  // aviso nunca aparecia. O texto ainda prometia "o sistema esta
                  // na bateria/gerador", que nao existe. Quem cobre queda de luz
                  // e o banner de sem comunicacao, pela ausencia de leituras.
                  if (_semComunicacaoAparelho) _buildBannerSemComunicacao(),
                  if (_aguardandoAparelho) _buildBannerAguardandoAparelho(),
                  LeituraAparelhoCard(
                    temperatura: temperatura,
                    umidade: umidade,
                    temperaturaAjuste: tempAjuste,
                    umidadeAjuste: umidAjuste,
                    sireneLigada: sireneLigada,
                    estadoTemperaturaAparelho: _estadoTemperaturaAparelho(),
                    folgaUmidade: folgaUmid,
                    onSilenciarAlarme: _silenciarAlarme,
                  ),
                  const SizedBox(height: 25),
                  PainelControle(
                    tempAjuste: tempAjuste,
                    umidAjuste: umidAjuste,
                    onMudarTemperatura: (novaTemp) {
                      final ajusteAnterior = tempAjuste;
                      // Abre a acomodacao ja no toque, para o LED nao piscar antes
                      // de o servidor confirmar a mudanca.
                      _detectorOscilacao.registrarMudancaAjusteTemperatura(
                        DateTime.now().millisecondsSinceEpoch,
                        leitura: temperatura,
                        ajusteAnterior: ajusteAnterior,
                        ajusteNovo: novaTemp,
                      );
                      setState(() {
                        tempAjuste = novaTemp;
                        _tempAjustePendente = novaTemp;
                      });
                      _agendarEnvioTemperatura(novaTemp, ajusteAnterior);
                    },
                    onMudarUmidade: (novaUmid) {
                      final ajusteAnterior = umidAjuste;
                      _detectorOscilacao.registrarMudancaAjusteUmidade(
                        DateTime.now().millisecondsSinceEpoch,
                        leitura: umidade,
                        ajusteAnterior: ajusteAnterior,
                        ajusteNovo: novaUmid,
                      );
                      setState(() {
                        umidAjuste = novaUmid;
                        _umidAjustePendente = novaUmid;
                      });
                      _agendarEnvioUmidade(novaUmid, ajusteAnterior);
                    },
                  ),
                  const SizedBox(height: 20),
                  EstufadaAtualCard(
                    ciclo: _cicloAtual,
                    onIniciar: _iniciarCiclo,
                    onFinalizar: _confirmarFinalizarCiclo,
                    onAbrirRelatorio: _abrirRelatorioEstufada,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Cala a sirene na hora e envia em segundo plano. Sem isto o icone so mudava
  // quando a leitura seguinte chegasse (ate 3 s em local, mais pela nuvem), e o
  // produtor com a sirene tocando no ouvido apertava de novo achando que o
  // toque nao pegou.
  //
  // Fogo nao entra: o aparelho ignora o silencio quando ha chama ou temperatura
  // de incendio, entao fingir que calou seria mentira - o icone voltaria
  // sozinho e a sirene continuaria tocando.
  Future<void> _silenciarAlarme() async {
    final silenciavel = !isFire;
    if (silenciavel) {
      setState(() {
        _silencioPendente = true;
        sireneLigada = false;
      });
    }

    // Mesmo caminho dos outros comandos: ele ja busca de novo ao dar certo,
    // atualiza as pendencias e explica a falha (sem conexao, chave invalida...)
    // em vez de um "nao deu" generico.
    final enviado = await _enviarComandoComFeedback({
      'modoSilencioso': true,
      'modoSilenciosoTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (!mounted || enviado || !silenciavel) return;

    // Nao chegou ao aparelho: a sirene continua tocando, entao o icone volta.
    setState(() {
      _silencioPendente = false;
      sireneLigada = true;
    });
  }

  // Silenciar os avisos do app SO desta estufa (fogo e sem comunicacao nunca
  // calam). Escopo por aparelho, diferente das preferencias globais da home.
  Widget _itemSilenciarAvisos() {
    final idHw = widget.idHardware ?? api.idHardware;
    return AnimatedBuilder(
      // Escuta tambem as preferencias globais: elas mandam no que este
      // interruptor pode prometer, entao a legenda tem que acompanhar.
      animation: Listenable.merge([
        SilenciamentoEstufas.instance,
        PreferenciasNotificacaoService.instance,
      ]),
      builder: (context, _) {
        final silenciada = SilenciamentoEstufas.instance.silenciada(idHw);
        return SwitchListTile(
          // Icone e interruptor acompanham o TITULO, nao o centro do item. A
          // legenda muda de tamanho conforme as configuracoes gerais, e sem
          // isto o sino afundava justamente nos casos de texto mais longo.
          isThreeLine: true,
          secondary: Icon(
            silenciada
                ? Icons.notifications_off_outlined
                : Icons.notifications_active_outlined,
            color: Colors.white70,
          ),
          // Curto como os vizinhos: o cabecalho do menu ja diz de qual estufa
          // sao estas acoes, e a secao acima ja diz que sao avisos.
          title: const Text(
            'Silenciar avisos',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            idHw == null
                ? 'Conecte o aparelho uma vez para poder silenciar.'
                : _legendaSilenciarAvisos(),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: silenciada,
          onChanged: idHw == null
              ? null
              : (v) => unawaited(_silenciarAvisos(idHw, v)),
        );
      },
    );
  }

  /// A promessa de que incendio e sem comunicacao continuam avisando so vale se
  /// eles estiverem ligados nas configuracoes gerais - o silenciamento por
  /// estufa nunca LIGA um aviso que o produtor desligou no global, so desliga os
  /// demais. Quando o global ja desligou um deles, a legenda diz isso em vez de
  /// prometer um aviso que nao vira.
  String _legendaSilenciarAvisos() {
    final prefs = PreferenciasNotificacaoService.instance.preferencias;
    // Os dois avisos de risco de fogo (chama no sensor e temperatura acima do
    // limite) contam como um so aqui: a legenda diz o que o produtor precisa
    // saber - se sobra algum aviso de fogo -, sem virar uma lista.
    final fogo =
        prefs.opcao(EventoNotificacao.incendio).notificar ||
        prefs.opcao(EventoNotificacao.temperaturaMuitoAlta).notificar;
    final semComunicacao = prefs
        .opcao(EventoNotificacao.semComunicacao)
        .notificar;

    if (fogo && semComunicacao) {
      return 'Incêndio e sem comunicação continuam avisando.';
    }
    if (!fogo && !semComunicacao) return 'Nada será avisado.';
    return fogo
        ? 'Só incêndio continua avisando.'
        : 'Só sem comunicação continua avisando.';
  }

  Future<void> _silenciarAvisos(String idHardware, bool silenciar) async {
    await SilenciamentoEstufas.instance.definir(idHardware, silenciar);
    // Reenvia as preferencias deste aparelho: o servidor passa a suprimir (ou
    // liberar) os avisos nao-criticos so desta estufa.
    await PushNotificationService.instance.atualizarPreferenciasDispositivo(
      idHardware: idHardware,
      tokenAcesso: widget.tokenAcesso,
    );
  }

  Widget _buildMenuEstufa() {
    return Drawer(
      backgroundColor: const Color(0xFF17191D),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Nome primeiro, rotulo embaixo — mesma ordem da barra do
                // monitoramento. O nome e o contexto (de qual estufa sao as
                // acoes); com "ACOES" em cima parecia que o nome pertencia a
                // uma secao chamada Acoes.
                children: [
                  Text(
                    widget.nomeEstufa,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'AÇÕES',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            _tituloMenu('CONEXÃO'),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Detalhes da conexão',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _mostrarDetalhesConexao();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Configurar aparelho',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Trocar o Wi-Fi ou a chave',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConfigurarAparelhoScreen(),
                  ),
                );
              },
            ),
            // Secao propria: silenciar aviso nao e assunto de conexao, e ficava
            // solto no fim daquela lista.
            const Divider(color: Colors.white12, height: 1),
            _tituloMenu('AVISOS'),
            _itemSilenciarAvisos(),
            const Divider(color: Colors.white12, height: 1),
            _tituloMenu('AÇÕES RÁPIDAS'),
            ListTile(
              leading: const Icon(
                Icons.alarm_add_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Agendar ajuste',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Para uma hora em que você não estará por perto',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AgendamentosScreen(
                      idEstufa: widget.idEstufa,
                      nomeEstufa: widget.nomeEstufa,
                      idHardware: widget.idHardware ?? api.idHardware,
                      tokenAcesso: widget.tokenAcesso,
                      temperaturaAtual: tempAjuste,
                      umidadeAtual: umidAjuste,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.white70),
              title: const Text(
                'Preparar nova estufada',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Ajusta para ${_tempNovaEstufada.toStringAsFixed(0)}°F e '
                '${_umidNovaEstufada.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _prepararNovaEstufada();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white70),
              title: const Text(
                'Apagar estufadas',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Remove relatórios',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GerenciarEstufadasScreen(
                      nomeEstufa: widget.nomeEstufa,
                      ipEstufa: widget.ipEstufa,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSemComunicacao() {
    final ms = _ultimaLeituraMs;
    final texto = ms == null
        ? 'Aparelho sem comunicação com a nuvem.'
        : 'Aparelho sem comunicação há ${_formatarTempoDecorrido(ms)}. '
              'Pode ser falta de energia ou de internet na estufa — verifique.';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Traduz o veredito do aparelho para o indicador de temperatura. Assim a
  /// sirene e o LED nunca se contradizem: os dois saem da mesma decisao.
  String _estadoTemperaturaAparelho() {
    switch (_corStatusAparelho) {
      case 'orange':
        return 'alta';
      case 'purple':
        return 'baixa';
      case 'red':
        // Fogo: o alarme e quem manda na tela, mas ainda vale mostrar o lado
        // em que a temperatura esta.
        return temperatura > tempAjuste ? 'alta' : 'ok';
      default:
        return 'ok';
    }
  }

  // Ambar, nao vermelho: nao e falha, e espera. O ajuste na tela ja e o novo,
  // mas o aparelho so busca o comando de tempos em tempos.
  Widget _buildBannerAguardandoAparelho() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Ajuste enviado. Aguardando a estufa aplicar — '
              'pode levar alguns segundos.',
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _descreverEstadoAparelho() {
    if (_semComunicacaoAparelho) {
      final ms = _ultimaLeituraMs;
      return ms == null
          ? 'Sem comunicação'
          : 'Sem comunicação há ${_formatarTempoDecorrido(ms)}';
    }
    return switch (_modoConexao) {
      'CONECTANDO' => 'Verificando...',
      'OFFLINE' => 'Não alcançado',
      'LOCAL' => 'Reportando (rede local)',
      _ => 'Reportando (via nuvem)',
    };
  }

  String _formatarTempoDecorrido(int desdeMs) {
    final minutos = (DateTime.now().millisecondsSinceEpoch - desdeMs) ~/ 60000;
    if (minutos < 1) return 'menos de 1 min';
    if (minutos < 60) return '$minutos min';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return resto == 0 ? '${horas}h' : '${horas}h ${resto}min';
  }

  Widget _tituloMenu(String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // Puxar a tela para baixo, no topo, atualiza a leitura na hora e sincroniza
  // os ajustes que ficaram pendentes - o mesmo que o item do menu fazia, mas
  // num gesto mais natural (como o "puxar para atualizar" de outros apps).
  Future<void> _onPullRefresh() async {
    await _monitor.atualizarAgora();
    await _sincronizarPendenciasSeNecessario(forcar: true);
  }

  Future<void> _prepararNovaEstufada() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Preparar nova estufada',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Ajustar para ${_tempNovaEstufada.toStringAsFixed(0)}°F e '
          '${_umidNovaEstufada.toStringAsFixed(0)}% para iniciar uma nova '
          'estufada?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajustar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final tempAnterior = tempAjuste;
    final umidAnterior = umidAjuste;
    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    _detectorOscilacao.registrarMudancaAjusteTemperatura(
      agoraMs,
      leitura: temperatura,
      ajusteAnterior: tempAnterior,
      ajusteNovo: _tempNovaEstufada,
    );
    _detectorOscilacao.registrarMudancaAjusteUmidade(
      agoraMs,
      leitura: umidade,
      ajusteAnterior: umidAnterior,
      ajusteNovo: _umidNovaEstufada,
    );
    setState(() {
      tempAjuste = _tempNovaEstufada;
      umidAjuste = _umidNovaEstufada;
      _tempAjustePendente = _tempNovaEstufada;
      _umidAjustePendente = _umidNovaEstufada;
    });
    // Usa o caminho normal de comando: a queda para <100 dispara a mesma
    // sugestao de "quer terminar a estufada?" quando ha um ciclo ativo.
    _agendarEnvioTemperatura(_tempNovaEstufada, tempAnterior);
    _agendarEnvioUmidade(_umidNovaEstufada, umidAnterior);
  }

  void _abrirRelatorioEstufada() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoricoScreen(
          nomeEstufa: widget.nomeEstufa,
          ipEstufa: widget.ipEstufa,
        ),
      ),
    );
  }

  Future<void> _sincronizarPendenciasSeNecessario({bool forcar = false}) async {
    if (_sincronizandoPendencias || !mounted) return;
    if (!forcar && _pendenciasSincronizacao <= 0) return;

    setState(() {
      _sincronizandoPendencias = true;
    });
    try {
      await api.sincronizarComandosPendentes();
    } finally {
      if (mounted) {
        setState(() {
          _sincronizandoPendencias = false;
        });
      }
      await _atualizarPendencias();
    }
  }

  Future<void> _carregarCicloAtual() async {
    final ciclo = await _monitoramentoRepository.buscarCicloAbertoPorIp(
      widget.ipEstufa,
    );
    if (!mounted) return;
    setState(() {
      _cicloAtual = ciclo;
      _sugestaoFimCicloExibida = false;
    });
  }

  Future<void> _iniciarCiclo() async {
    final ciclo = await _monitoramentoRepository.iniciarCicloSecagem(
      ipEstufa: widget.ipEstufa,
      nomeEstufa: widget.nomeEstufa,
    );
    if (!mounted) return;
    setState(() {
      _cicloAtual = ciclo;
      _sugestaoFimCicloExibida = false;
      _ultimoRegistroHistoricoMs = 0;
      _detectorOscilacao.reiniciar();
    });
    _registrarEventoCiclo(
      tipo: 'inicio_estufada',
      severidade: 'info',
      descricao: 'Estufada iniciada pelo operador.',
      registrarLeitura: false,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Estufada iniciada.')));
    _registrarHistoricoSeNecessario(
      temperaturaAtual: temperatura,
      umidadeAtual: umidade,
      temperaturaAjusteAtual: tempAjuste,
      umidadeAjusteAtual: umidAjuste,
      avisoAtual: avisoEmergencia,
      alertaIncendioAtual: sireneLigada,
      forcar: true,
    );
  }

  Future<void> _confirmarFinalizarCiclo() async {
    final ciclo = _cicloAtual;
    if (ciclo == null) return;

    final confirmar = await confirmarFinalizacaoEstufada(context);
    if (confirmar) {
      await _finalizarCiclo(ciclo.id);
    }
  }

  Future<void> _finalizarCiclo(int cicloId) async {
    _registrarEventoCiclo(
      tipo: 'fim_estufada',
      severidade: 'info',
      descricao: 'Estufada finalizada pelo operador.',
    );
    await _monitoramentoRepository.finalizarCicloSecagem(cicloId);
    if (!mounted) return;
    setState(() {
      _cicloAtual = null;
      _sugestaoFimCicloExibida = false;
      _detectorOscilacao.reiniciar();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Estufada finalizada.')));
  }

  Future<void> _sugerirFinalizacaoPorQuedaAjuste() async {
    if (!mounted || _cicloAtual == null) return;

    final confirmar = await confirmarSugestaoFimEstufada(context);

    if (confirmar && _cicloAtual != null) {
      await _finalizarCiclo(_cicloAtual!.id);
    }
  }

  void _registrarQuedaConexaoSeNecessario() {
    if (_cicloAtual == null) return;
    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    if (_rastreadorConexao.avaliarQueda(agoraMs)) {
      _registrarEventoCiclo(
        tipo: 'queda_conexao',
        severidade: 'alerta',
        descricao: 'A estufa ficou sem conex\u00E3o por mais de 2 minutos.',
      );
    }
  }

  void _registrarRetornoConexaoSeNecessario() {
    if (_rastreadorConexao.avaliarRetorno()) {
      _registrarEventoCiclo(
        tipo: 'retorno_conexao',
        severidade: 'info',
        descricao: 'A conex\u00E3o da estufa foi restabelecida.',
      );
    }
  }

  void _processarEventosDoCiclo({
    required double temperaturaAtual,
    required double umidadeAtual,
    required double temperaturaAjusteAtual,
    required double umidadeAjusteAtual,
    required bool alertaIncendioAtual,
    required bool riscoIncendioAtual,
    required String avisoAtual,
  }) {
    if (_cicloAtual == null) {
      _ultimoAlertaIncendio = alertaIncendioAtual;
      return;
    }

    // Nao ha evento de queda/retorno de energia: sem sensor de tensao o
    // aparelho reporta `temEnergia` sempre true, e a transicao nunca ocorria.
    // Volta quando o sensor existir.
    if (alertaIncendioAtual && _ultimoAlertaIncendio != true) {
      final ehIncendio = riscoIncendioAtual;
      _registrarEventoCiclo(
        tipo: ehIncendio ? 'alerta_incendio' : 'alarme_processo',
        severidade: ehIncendio ? 'critico' : 'alerta',
        descricao: ehIncendio
            ? 'Alerta de inc\u00EAndio acionado.'
            : 'Alarme acionado: ${_formatarAvisoAlarme(avisoAtual)}.',
        temperaturaAtual: temperaturaAtual,
        umidadeAtual: umidadeAtual,
        temperaturaAjusteAtual: temperaturaAjusteAtual,
        umidadeAjusteAtual: umidadeAjusteAtual,
        avisoAtual: avisoAtual,
        alertaIncendioAtual: alertaIncendioAtual,
      );
    } else if (!alertaIncendioAtual && _ultimoAlertaIncendio == true) {
      _registrarEventoCiclo(
        tipo: 'alarme_normalizado',
        severidade: 'info',
        descricao: 'Alarme normalizado.',
        temperaturaAtual: temperaturaAtual,
        umidadeAtual: umidadeAtual,
        temperaturaAjusteAtual: temperaturaAjusteAtual,
        umidadeAjusteAtual: umidadeAjusteAtual,
        avisoAtual: avisoAtual,
        alertaIncendioAtual: alertaIncendioAtual,
      );
    }
    _ultimoAlertaIncendio = alertaIncendioAtual;

    final agoraOscMs = DateTime.now().millisecondsSinceEpoch;
    final eventoTemp = _detectorOscilacao.avaliarTemperatura(
      leitura: temperaturaAtual,
      ajuste: temperaturaAjusteAtual,
      nowMs: agoraOscMs,
    );
    if (eventoTemp != null) {
      _registrarEventoOscilacao(
        eventoTemp,
        temperaturaAtual: temperaturaAtual,
        umidadeAtual: umidadeAtual,
        temperaturaAjusteAtual: temperaturaAjusteAtual,
        umidadeAjusteAtual: umidadeAjusteAtual,
        avisoAtual: avisoAtual,
        alertaIncendioAtual: alertaIncendioAtual,
      );
    }
    final eventoUmid = _detectorOscilacao.avaliarUmidade(
      leitura: umidadeAtual,
      ajuste: umidadeAjusteAtual,
      nowMs: agoraOscMs,
    );
    if (eventoUmid != null) {
      _registrarEventoOscilacao(
        eventoUmid,
        temperaturaAtual: temperaturaAtual,
        umidadeAtual: umidadeAtual,
        temperaturaAjusteAtual: temperaturaAjusteAtual,
        umidadeAjusteAtual: umidadeAjusteAtual,
        avisoAtual: avisoAtual,
        alertaIncendioAtual: alertaIncendioAtual,
      );
    }
  }

  void _registrarEventoOscilacao(
    EventoOscilacao evento, {
    required double temperaturaAtual,
    required double umidadeAtual,
    required double temperaturaAjusteAtual,
    required double umidadeAjusteAtual,
    required String avisoAtual,
    required bool alertaIncendioAtual,
  }) {
    _registrarEventoCiclo(
      tipo: evento.tipo,
      severidade: evento.severidade,
      descricao: evento.descricao,
      valorAnterior: evento.valorAnterior,
      valorAtual: evento.valorAtual,
      temperaturaAtual: temperaturaAtual,
      umidadeAtual: umidadeAtual,
      temperaturaAjusteAtual: temperaturaAjusteAtual,
      umidadeAjusteAtual: umidadeAjusteAtual,
      avisoAtual: avisoAtual,
      alertaIncendioAtual: alertaIncendioAtual,
    );
  }

  String _formatarAvisoAlarme(String aviso) {
    return aviso
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll('Temp ', 'Temperatura ')
        .replaceAll('Umid ', 'Umidade ')
        .trim();
  }

  void _registrarEventoCiclo({
    required String tipo,
    required String severidade,
    required String descricao,
    double? valorAnterior,
    double? valorAtual,
    double? temperaturaAtual,
    double? umidadeAtual,
    double? temperaturaAjusteAtual,
    double? umidadeAjusteAtual,
    String? avisoAtual,
    bool? alertaIncendioAtual,
    bool registrarLeitura = true,
  }) {
    final ciclo = _cicloAtual;
    if (ciclo == null) return;

    unawaited(
      _monitoramentoRepository.salvarEventoCiclo(
        ipEstufa: widget.ipEstufa,
        nomeEstufa: widget.nomeEstufa,
        cicloId: ciclo.id,
        tipo: tipo,
        severidade: severidade,
        descricao: descricao,
        valorAnterior: valorAnterior,
        valorAtual: valorAtual,
      ),
    );

    if (registrarLeitura) {
      _registrarHistoricoSeNecessario(
        temperaturaAtual: temperaturaAtual ?? temperatura,
        umidadeAtual: umidadeAtual ?? umidade,
        temperaturaAjusteAtual: temperaturaAjusteAtual ?? tempAjuste,
        umidadeAjusteAtual: umidadeAjusteAtual ?? umidAjuste,
        avisoAtual: avisoAtual ?? avisoEmergencia,
        alertaIncendioAtual: alertaIncendioAtual ?? sireneLigada,
        porEvento: true,
      );
    }
  }

  Future<void> _mostrarDetalhesConexao() async {
    final pendencias = await _monitoramentoRepository.listarPendenciasPorIp(
      api.localBaseUrl,
      limite: 5,
    );
    if (!mounted) return;

    await mostrarDetalhesConexaoDialog(
      context: context,
      // Mesmo rotulo do indicador na AppBar, para o menu nao dizer "NUVEM"
      // enquanto a tela avisa que o aparelho esta mudo.
      modoConexao: _semComunicacaoAparelho ? 'SEM SINAL' : _modoConexao,
      estadoAparelho: _descreverEstadoAparelho(),
      baseUrlAtiva: api.baseUrlAtiva,
      localBaseUrl: api.localBaseUrl,
      cloudBaseUrl: api.cloudBaseUrl,
      temTokenConfigurado: api.temTokenConfigurado,
      totalPendencias: _pendenciasSincronizacao,
      pendencias: pendencias,
      alcanceConhecido: api.ultimoAlcance,
      testarAlcance: () => api.verificarConexoes(forcar: true),
      sincronizandoPendencias: _sincronizandoPendencias,
      onLimparFila: () => unawaited(_confirmarLimpezaPendencias()),
      onSincronizar: () =>
          unawaited(_sincronizarPendenciasSeNecessario(forcar: true)),
    );
  }

  Future<void> _confirmarLimpezaPendencias() async {
    final confirmar = await confirmarLimpezaPendencias(context);
    if (!confirmar) return;

    final removidas = await _monitoramentoRepository.limparPendenciasPorIp(
      api.localBaseUrl,
    );
    await _atualizarPendencias();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pend\u00EAncias removidas: $removidas')),
    );
  }

  Future<void> _atualizarPendencias() async {
    final total = await _monitoramentoRepository.contarPendenciasPorIp(
      api.localBaseUrl,
    );
    if (!mounted) return;
    setState(() {
      _pendenciasSincronizacao = total;
    });
  }

  void _agendarEnvioTemperatura(double novaTemp, double ajusteAnterior) {
    _debounceTemperatura?.cancel();
    _debounceTemperatura = Timer(const Duration(milliseconds: 1000), () {
      unawaited(
        _enviarComandoComFeedback({
          'temperaturaMeta': novaTemp,
          'tempTimestamp': DateTime.now().millisecondsSinceEpoch,
        }).then((sucesso) {
          if (novaTemp != ajusteAnterior) {
            _registrarEventoCiclo(
              tipo: 'ajuste_temperatura',
              severidade: 'info',
              descricao:
                  'Ajuste de temperatura alterado para ${novaTemp.toStringAsFixed(0)}\u00B0F.',
              valorAnterior: ajusteAnterior,
              valorAtual: novaTemp,
            );
          }
          if (!mounted || !sucesso || _tempAjustePendente != novaTemp) return;
          setState(() {
            _tempAjustePendente = null;
          });
        }),
      );
    });
  }

  void _agendarEnvioUmidade(double novaUmid, double ajusteAnterior) {
    _debounceUmidade?.cancel();
    _debounceUmidade = Timer(const Duration(milliseconds: 1000), () {
      unawaited(
        _enviarComandoComFeedback({
          'umidadeMeta': novaUmid,
          'umidTimestamp': DateTime.now().millisecondsSinceEpoch,
        }).then((sucesso) {
          if (novaUmid != ajusteAnterior) {
            _registrarEventoCiclo(
              tipo: 'ajuste_umidade',
              severidade: 'info',
              descricao:
                  'Ajuste de umidade alterado para ${novaUmid.toStringAsFixed(0)}%.',
              valorAnterior: ajusteAnterior,
              valorAtual: novaUmid,
            );
          }
          if (!mounted || !sucesso || _umidAjustePendente != novaUmid) return;
          setState(() {
            _umidAjustePendente = null;
          });
        }),
      );
    });
  }

  Future<bool> _enviarComandoComFeedback(Map<String, dynamic> payload) async {
    final sucesso = await api.enviarSincronizacao(payload);
    final falha = api.ultimaFalhaComando;
    // Busca fora do ritmo do timer: esta tela e o card da home compartilham o
    // monitor, entao os dois refletem o comando juntos e na hora.
    if (sucesso) unawaited(_monitor.atualizarAgora());
    await _atualizarPendencias();
    if (!mounted) return sucesso;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(_mensagemEnvioComando(sucesso: sucesso, falha: falha)),
        duration: const Duration(seconds: 2),
      ),
    );
    return sucesso;
  }

  String _mensagemEnvioComando({
    required bool sucesso,
    required ApiCommandFailure falha,
  }) {
    if (sucesso) return 'Comando aplicado.';

    return switch (falha) {
      ApiCommandFailure.unauthorized =>
        'Chave inv\u00E1lida. Verifique a chave de acesso da estufa.',
      ApiCommandFailure.invalidRequest =>
        'Comando recusado. Verifique os dados enviados.',
      ApiCommandFailure.serverError =>
        'Servidor indispon\u00EDvel. Comando salvo para sincronizar depois.',
      ApiCommandFailure.offline || ApiCommandFailure.none =>
        'Sem conex\u00E3o agora. Comando salvo para sincronizar depois.',
    };
  }
}
