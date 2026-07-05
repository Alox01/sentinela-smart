import 'dart:async';
import 'package:flutter/material.dart';

import '../features/monitoramento/dialogs/detalhes_conexao_dialog.dart';
import '../features/monitoramento/dialogs/monitoramento_confirm_dialogs.dart';
import '../features/monitoramento/services/monitoramento_repository.dart';
import '../features/monitoramento/widgets/alerta_monitoramento_banner.dart';
import '../features/monitoramento/widgets/estufada_atual_card.dart';
import '../features/monitoramento/widgets/indicador_conexao.dart';
import '../features/monitoramento/widgets/leitura_aparelho_card.dart';
import '../models/ciclo_secagem_entity.dart';
import '../services/api_service.dart';
import '../services/isar_service.dart';
import '../widgets/painel_controle.dart';
import 'historico_screen.dart';

class MonitoramentoScreen extends StatefulWidget {
  final String nomeEstufa;
  final String ipEstufa;
  final String? tokenAcesso;

  const MonitoramentoScreen({
    super.key,
    required this.nomeEstufa,
    required this.ipEstufa,
    this.tokenAcesso,
  });

  @override
  State<MonitoramentoScreen> createState() => _MonitoramentoScreenState();
}

class _MonitoramentoScreenState extends State<MonitoramentoScreen> {
  static const int _intervaloRegistroHistoricoMs = 10 * 60 * 1000;
  static const int _tempoQuedaConexaoMs = 2 * 60 * 1000;
  static const int _tempoOscilacaoAtencaoMs = 10 * 60 * 1000;
  static const int _tempoOscilacaoCriticaMs = 5 * 60 * 1000;
  static const double _toleranciaOscilacao = 5;

  double temperatura = 0.0;
  String avisoEmergencia = '';
  double umidade = 0.0;
  double tempAjuste = 0.0;
  double umidAjuste = 0.0;
  double? _tempAjustePendente;
  double? _umidAjustePendente;

  bool isFire = false;
  bool sireneLigada = false;
  int _pendenciasSincronizacao = 0;
  bool _sincronizandoPendencias = false;
  String _modoConexao = 'OFFLINE';
  int _ultimoRegistroHistoricoMs = 0;
  CicloSecagemEntity? _cicloAtual;
  double? _ultimoTempAjusteServidor;
  bool? _ultimoAlertaIncendio;
  int? _offlineDesdeMs;
  bool _quedaConexaoRegistrada = false;
  String _estadoOscilacaoTemperatura = 'normal';
  String? _estadoOscilacaoTemperaturaPendente;
  int? _oscilacaoTemperaturaDesdeMs;
  int _ultimoRegistroOscilacaoTemperaturaMs = 0;
  String _estadoOscilacaoUmidade = 'normal';
  String? _estadoOscilacaoUmidadePendente;
  int? _oscilacaoUmidadeDesdeMs;
  int _ultimoRegistroOscilacaoUmidadeMs = 0;
  bool _sugestaoFimCicloExibida = false;

  Timer? timer;
  Timer? _debounceTemperatura;
  Timer? _debounceUmidade;
  late ApiService api;
  final MonitoramentoRepository _monitoramentoRepository =
      MonitoramentoRepository(IsarService.instance);

  @override
  void initState() {
    super.initState();
    api = ApiService(widget.ipEstufa, token: widget.tokenAcesso);
    unawaited(_carregarCicloAtual());
    unawaited(_atualizarPendencias());
    unawaited(atualizarTela());
    timer = Timer.periodic(const Duration(seconds: 1), (_) => atualizarTela());
  }

  @override
  void dispose() {
    timer?.cancel();
    _debounceTemperatura?.cancel();
    _debounceUmidade?.cancel();
    super.dispose();
  }

  Future<void> atualizarTela() async {
    final dados = await api.buscarStatus();
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
    final ajusteTempAnterior = _ultimoTempAjusteServidor;
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

      temperatura = novaTemperatura;
      umidade = novaUmidade;
      tempAjuste = _tempAjustePendente ?? novoTempAjuste;
      umidAjuste = _umidAjustePendente ?? novoUmidAjuste;
      avisoEmergencia = novoAviso;
      sireneLigada = novaSireneLigada;
      isFire = fogoDetectado;
      _modoConexao = api.modoConexao;
      _ultimoTempAjusteServidor = novoTempAjuste;
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
  }) {
    if (_cicloAtual == null) return;

    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    if (!forcar &&
        (agoraMs - _ultimoRegistroHistoricoMs) <
            _intervaloRegistroHistoricoMs) {
      return;
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
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;
    final isSuperaquecimentoNaoIntencional =
        temperatura >= 165.0 && temperatura > (tempAjuste + 2.0);

    return Scaffold(
      backgroundColor: corFundo,
      appBar: AppBar(
        leading: IconButton(
          iconSize: 20,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        // Titulo alinhado a esquerda: nomes longos ganham o espaco livre e
        // cortam com reticencias, em vez de encolher espremidos entre a seta
        // e o indicador de conexao.
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nomeEstufa.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: telaEstreita ? 17 : 18,
                letterSpacing: telaEstreita ? 0.7 : 1,
              ),
            ),
            Text(
              'MONITORAMENTO',
              maxLines: 1,
              style: TextStyle(
                fontSize: telaEstreita ? 9 : 12,
                color: Colors.white70,
                letterSpacing: telaEstreita ? 1.4 : 2,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        elevation: 0,
        actions: [
          IndicadorConexao(
            modoConexao: _modoConexao,
            sincronizando: _sincronizandoPendencias,
            pendencias: _pendenciasSincronizacao,
          ),
          IconButton(
            visualDensity: telaEstreita ? VisualDensity.compact : null,
            iconSize: telaEstreita ? 20 : 24,
            constraints: telaEstreita
                ? const BoxConstraints.tightFor(width: 32, height: 48)
                : null,
            onPressed: _mostrarDetalhesConexao,
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Detalhes da conex\u00E3o',
          ),
          IconButton(
            visualDensity: telaEstreita ? VisualDensity.compact : null,
            iconSize: telaEstreita ? 20 : 24,
            constraints: telaEstreita
                ? const BoxConstraints.tightFor(width: 32, height: 48)
                : null,
            onPressed: _sincronizandoPendencias
                ? null
                : () => _sincronizarPendenciasSeNecessario(forcar: true),
            icon: Icon(
              _sincronizandoPendencias ? Icons.sync : Icons.sync_problem,
            ),
            tooltip: 'Sincronizar pend\u00EAncias',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                LeituraAparelhoCard(
                  temperatura: temperatura,
                  umidade: umidade,
                  temperaturaAjuste: tempAjuste,
                  umidadeAjuste: umidAjuste,
                  sireneLigada: sireneLigada,
                  onSilenciarAlarme: api.silenciarAlarme,
                ),
                const SizedBox(height: 25),
                PainelControle(
                  tempAjuste: tempAjuste,
                  umidAjuste: umidAjuste,
                  onMudarTemperatura: (novaTemp) {
                    final ajusteAnterior = tempAjuste;
                    setState(() {
                      tempAjuste = novaTemp;
                      _tempAjustePendente = novaTemp;
                    });
                    _agendarEnvioTemperatura(novaTemp, ajusteAnterior);
                  },
                  onMudarUmidade: (novaUmid) {
                    final ajusteAnterior = umidAjuste;
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
    );
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
      _estadoOscilacaoTemperatura = 'normal';
      _estadoOscilacaoTemperaturaPendente = null;
      _oscilacaoTemperaturaDesdeMs = null;
      _ultimoRegistroOscilacaoTemperaturaMs = 0;
      _estadoOscilacaoUmidade = 'normal';
      _estadoOscilacaoUmidadePendente = null;
      _oscilacaoUmidadeDesdeMs = null;
      _ultimoRegistroOscilacaoUmidadeMs = 0;
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
      _estadoOscilacaoTemperatura = 'normal';
      _estadoOscilacaoTemperaturaPendente = null;
      _oscilacaoTemperaturaDesdeMs = null;
      _ultimoRegistroOscilacaoTemperaturaMs = 0;
      _estadoOscilacaoUmidade = 'normal';
      _estadoOscilacaoUmidadePendente = null;
      _oscilacaoUmidadeDesdeMs = null;
      _ultimoRegistroOscilacaoUmidadeMs = 0;
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
    final ciclo = _cicloAtual;
    if (ciclo == null || _quedaConexaoRegistrada) return;

    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    _offlineDesdeMs ??= agoraMs;
    if ((agoraMs - _offlineDesdeMs!) < _tempoQuedaConexaoMs) return;

    _quedaConexaoRegistrada = true;
    _registrarEventoCiclo(
      tipo: 'queda_conexao',
      severidade: 'alerta',
      descricao: 'A estufa ficou sem conex\u00E3o por mais de 2 minutos.',
    );
  }

  void _registrarRetornoConexaoSeNecessario() {
    if (_quedaConexaoRegistrada) {
      _registrarEventoCiclo(
        tipo: 'retorno_conexao',
        severidade: 'info',
        descricao: 'A conex\u00E3o da estufa foi restabelecida.',
      );
    }
    _offlineDesdeMs = null;
    _quedaConexaoRegistrada = false;
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

    _processarOscilacaoTemperatura(
      temperaturaAtual: temperaturaAtual,
      umidadeAtual: umidadeAtual,
      temperaturaAjusteAtual: temperaturaAjusteAtual,
      umidadeAjusteAtual: umidadeAjusteAtual,
      avisoAtual: avisoAtual,
      alertaIncendioAtual: alertaIncendioAtual,
    );
    _processarOscilacaoUmidade(
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

  void _processarOscilacaoTemperatura({
    required double temperaturaAtual,
    required double umidadeAtual,
    required double temperaturaAjusteAtual,
    required double umidadeAjusteAtual,
    required String avisoAtual,
    required bool alertaIncendioAtual,
  }) {
    final diferenca = temperaturaAtual - temperaturaAjusteAtual;
    final diferencaAbs = diferenca.abs();
    final estadoAlvo = diferencaAbs > 20
        ? 'critico'
        : diferencaAbs > _toleranciaOscilacao
        ? 'atencao'
        : 'normal';

    if (estadoAlvo == 'normal') {
      _estadoOscilacaoTemperaturaPendente = null;
      _oscilacaoTemperaturaDesdeMs = null;
      _ultimoRegistroOscilacaoTemperaturaMs = 0;
      if (_estadoOscilacaoTemperatura != 'normal') {
        _estadoOscilacaoTemperatura = 'normal';
        _registrarEventoCiclo(
          tipo: 'oscilacao_temperatura_normalizada',
          severidade: 'info',
          descricao: 'Temperatura voltou para a faixa proxima do ajuste.',
          valorAtual: temperaturaAtual,
          temperaturaAtual: temperaturaAtual,
          umidadeAtual: umidadeAtual,
          temperaturaAjusteAtual: temperaturaAjusteAtual,
          umidadeAjusteAtual: umidadeAjusteAtual,
          avisoAtual: avisoAtual,
          alertaIncendioAtual: alertaIncendioAtual,
        );
      }
      return;
    }

    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    if (_estadoOscilacaoTemperaturaPendente != estadoAlvo) {
      _estadoOscilacaoTemperaturaPendente = estadoAlvo;
      _oscilacaoTemperaturaDesdeMs = agoraMs;
      return;
    }

    final tempoMinimo = estadoAlvo == 'critico'
        ? _tempoOscilacaoCriticaMs
        : _tempoOscilacaoAtencaoMs;
    final desdeMs = _oscilacaoTemperaturaDesdeMs ?? agoraMs;
    if ((agoraMs - desdeMs) < tempoMinimo) return;
    if (_estadoOscilacaoTemperatura == estadoAlvo) {
      if ((agoraMs - _ultimoRegistroOscilacaoTemperaturaMs) <
          _intervaloRegistroHistoricoMs) {
        return;
      }
      _ultimoRegistroOscilacaoTemperaturaMs = agoraMs;
      _registrarEventoCiclo(
        tipo: 'oscilacao_temperatura_continua',
        severidade: estadoAlvo == 'critico' ? 'critico' : 'alerta',
        descricao:
            'Temperatura ainda fora do ajuste (${diferencaAbs.toStringAsFixed(0)}\u00B0F de diferen\u00E7a).',
        valorAnterior: temperaturaAjusteAtual,
        valorAtual: temperaturaAtual,
        temperaturaAtual: temperaturaAtual,
        umidadeAtual: umidadeAtual,
        temperaturaAjusteAtual: temperaturaAjusteAtual,
        umidadeAjusteAtual: umidadeAjusteAtual,
        avisoAtual: avisoAtual,
        alertaIncendioAtual: alertaIncendioAtual,
      );
      return;
    }

    _estadoOscilacaoTemperatura = estadoAlvo;
    _ultimoRegistroOscilacaoTemperaturaMs = agoraMs;
    final direcao = diferenca > 0 ? 'acima' : 'abaixo';
    final severidade = estadoAlvo == 'critico' ? 'critico' : 'alerta';
    final limiteTexto = estadoAlvo == 'critico' ? '20\u00B0F' : '10\u00B0F';
    _registrarEventoCiclo(
      tipo: 'oscilacao_temperatura',
      severidade: severidade,
      descricao:
          'Temperatura $direcao do ajuste por mais de $limiteTexto (${diferencaAbs.toStringAsFixed(0)}\u00B0F de diferen\u00E7a).',
      valorAnterior: temperaturaAjusteAtual,
      valorAtual: temperaturaAtual,
      temperaturaAtual: temperaturaAtual,
      umidadeAtual: umidadeAtual,
      temperaturaAjusteAtual: temperaturaAjusteAtual,
      umidadeAjusteAtual: umidadeAjusteAtual,
      avisoAtual: avisoAtual,
      alertaIncendioAtual: alertaIncendioAtual,
    );
  }

  void _processarOscilacaoUmidade({
    required double temperaturaAtual,
    required double umidadeAtual,
    required double temperaturaAjusteAtual,
    required double umidadeAjusteAtual,
    required String avisoAtual,
    required bool alertaIncendioAtual,
  }) {
    final diferenca = umidadeAtual - umidadeAjusteAtual;
    final diferencaAbs = diferenca.abs();
    final estadoAlvo = diferencaAbs > 20
        ? 'critico'
        : diferencaAbs > _toleranciaOscilacao
        ? 'atencao'
        : 'normal';

    if (estadoAlvo == 'normal') {
      _estadoOscilacaoUmidadePendente = null;
      _oscilacaoUmidadeDesdeMs = null;
      _ultimoRegistroOscilacaoUmidadeMs = 0;
      if (_estadoOscilacaoUmidade != 'normal') {
        _estadoOscilacaoUmidade = 'normal';
        _registrarEventoCiclo(
          tipo: 'oscilacao_umidade_normalizada',
          severidade: 'info',
          descricao: 'Umidade voltou para a faixa proxima do ajuste.',
          valorAtual: umidadeAtual,
          temperaturaAtual: temperaturaAtual,
          umidadeAtual: umidadeAtual,
          temperaturaAjusteAtual: temperaturaAjusteAtual,
          umidadeAjusteAtual: umidadeAjusteAtual,
          avisoAtual: avisoAtual,
          alertaIncendioAtual: alertaIncendioAtual,
        );
      }
      return;
    }

    final agoraMs = DateTime.now().millisecondsSinceEpoch;
    if (_estadoOscilacaoUmidadePendente != estadoAlvo) {
      _estadoOscilacaoUmidadePendente = estadoAlvo;
      _oscilacaoUmidadeDesdeMs = agoraMs;
      return;
    }

    final tempoMinimo = estadoAlvo == 'critico'
        ? _tempoOscilacaoCriticaMs
        : _tempoOscilacaoAtencaoMs;
    final desdeMs = _oscilacaoUmidadeDesdeMs ?? agoraMs;
    if ((agoraMs - desdeMs) < tempoMinimo) return;
    if (_estadoOscilacaoUmidade == estadoAlvo) {
      if ((agoraMs - _ultimoRegistroOscilacaoUmidadeMs) <
          _intervaloRegistroHistoricoMs) {
        return;
      }
      _ultimoRegistroOscilacaoUmidadeMs = agoraMs;
      _registrarEventoCiclo(
        tipo: 'oscilacao_umidade_continua',
        severidade: estadoAlvo == 'critico' ? 'critico' : 'alerta',
        descricao:
            'Umidade ainda fora do ajuste (${diferencaAbs.toStringAsFixed(0)}% de diferen\u00E7a).',
        valorAnterior: umidadeAjusteAtual,
        valorAtual: umidadeAtual,
        temperaturaAtual: temperaturaAtual,
        umidadeAtual: umidadeAtual,
        temperaturaAjusteAtual: temperaturaAjusteAtual,
        umidadeAjusteAtual: umidadeAjusteAtual,
        avisoAtual: avisoAtual,
        alertaIncendioAtual: alertaIncendioAtual,
      );
      return;
    }

    _estadoOscilacaoUmidade = estadoAlvo;
    _ultimoRegistroOscilacaoUmidadeMs = agoraMs;
    final direcao = diferenca > 0 ? 'acima' : 'abaixo';
    final severidade = estadoAlvo == 'critico' ? 'critico' : 'alerta';
    final limiteTexto = estadoAlvo == 'critico' ? '20%' : '5%';
    _registrarEventoCiclo(
      tipo: 'oscilacao_umidade',
      severidade: severidade,
      descricao:
          'Umidade $direcao do ajuste por mais de $limiteTexto (${diferencaAbs.toStringAsFixed(0)}% de diferen\u00E7a).',
      valorAnterior: umidadeAjusteAtual,
      valorAtual: umidadeAtual,
      temperaturaAtual: temperaturaAtual,
      umidadeAtual: umidadeAtual,
      temperaturaAjusteAtual: temperaturaAjusteAtual,
      umidadeAjusteAtual: umidadeAjusteAtual,
      avisoAtual: avisoAtual,
      alertaIncendioAtual: alertaIncendioAtual,
    );
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
        forcar: true,
      );
    }
  }

  Future<void> _mostrarDetalhesConexao() async {
    final pendencias = await _monitoramentoRepository.listarPendenciasPorIp(
      api.localBaseUrl,
      limite: 5,
    );
    final probesFuture = api.verificarConexoes();
    if (!mounted) return;

    await mostrarDetalhesConexaoDialog(
      context: context,
      modoConexao: _modoConexao,
      baseUrlAtiva: api.baseUrlAtiva,
      localBaseUrl: api.localBaseUrl,
      cloudBaseUrl: api.cloudBaseUrl,
      temTokenConfigurado: api.temTokenConfigurado,
      totalPendencias: _pendenciasSincronizacao,
      pendencias: pendencias,
      probesFuture: probesFuture,
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
