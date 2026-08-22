import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ciclo_secagem_entity.dart';
import '../models/evento_ciclo_entity.dart';
import '../models/historico_leitura_entity.dart';
import '../features/relatorio_estufada/duracao_estufada.dart';
import '../features/relatorio_estufada/services/relatorio_estufada_repository.dart';
import '../features/relatorio_estufada/widgets/grafico_estufada_card.dart';
import 'package:printing/printing.dart';

import '../features/relatorio_estufada/services/relatorio_csv_service.dart';
import '../features/relatorio_estufada/services/relatorio_pdf_service.dart';
import '../services/api_service.dart';
import '../services/csv_exporter.dart';
import '../services/isar_service.dart';
import '../features/relatorio_estufada/widgets/eventos_estufada_card.dart';
import '../features/relatorio_estufada/widgets/resumo_estufada_card.dart';
import '../features/relatorio_estufada/widgets/seletor_estufada_periodo_card.dart';

class HistoricoScreen extends StatefulWidget {
  final String nomeEstufa;
  final String ipEstufa;

  /// Identifica o aparelho na nuvem. Sem ele o relatorio remoto nao tem como
  /// pedir o historico DESTA estufa.
  final String? idHardware;

  const HistoricoScreen({
    super.key,
    required this.nomeEstufa,
    required this.ipEstufa,
    this.idHardware,
  });

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  static const Duration _intervaloMinimoFiltro = Duration(hours: 1);
  static const _tituloSecaoStyle = TextStyle(
    color: Colors.white54,
    fontSize: 12,
    letterSpacing: 1,
  );
  static const _csvService = RelatorioCsvService();
  static const _pdfService = RelatorioPdfService();
  final RelatorioEstufadaRepository _relatorioRepository =
      RelatorioEstufadaRepository(IsarService.instance);
  // COM o idHardware: sem ele, `/historico` na nuvem cai no aparelho padrao e
  // devolve o historico do SIMULADOR. O `/status` ja tratava isso; esta rota
  // nao, e o relatorio vinha vazio ou com dado de outra estufa.
  late final ApiService _api = ApiService(
    widget.ipEstufa,
    idHardware: widget.idHardware,
  );

  late Future<DadosRelatorioEstufada> _dadosFuture;
  List<HistoricoLeituraEntity> _leiturasBrutas = [];
  // Histórico já mesclado com a nuvem (preenchido em segundo plano) e controle
  // de qual ciclo já foi buscado, para não travar a tela esperando a rede.
  List<HistoricoLeituraEntity>? _leiturasNuvem;
  int? _cicloNuvemCarregadoId;
  int? _cicloNuvemEmProgresso;
  List<CicloSecagemEntity> _ciclos = [];
  // Posicao sequencial (1, 2, 3...) por ordem de inicio, desacoplada do id do
  // banco, para o rotulo nao ter "buracos" quando uma estufada e apagada.
  final Map<int, int> _posicaoPorCiclo = {};
  List<EventoCicloEntity> _eventos = [];
  int? _cicloSelecionadoId;
  DateTime? _inicioFiltro;
  DateTime? _fimFiltro;
  bool _graficoTemperatura = true;
  bool _mostrarGrafico = false;
  Timer? _timerGrafico;

  @override
  void initState() {
    super.initState();
    // Aproveita o relatorio que o monitoramento adiantou. Sem ele, e a carga
    // normal: nada aqui depende da precarga ter acontecido.
    _dadosFuture =
        _relatorioRepository.consumirPrecarga(widget.ipEstufa) ??
        _carregarDadosRelatorio();
  }

  @override
  void dispose() {
    _timerGrafico?.cancel();
    super.dispose();
  }

  /// Recarrega o relatorio do zero, pelo puxar-para-atualizar. Devolve um
  /// Future porque o gesto precisa esperar a carga terminar para a animacao
  /// fechar na hora certa, em vez de sumir antes dos dados chegarem.
  Future<void> _recarregarRelatorio() async {
    if (!mounted) return;
    final futuro = _carregarDadosRelatorio();
    setState(() {
      _resetarExibicaoGrafico();
      _cicloSelecionadoId = null;
      _dadosFuture = futuro;
    });
    await futuro;
  }

  Future<DadosRelatorioEstufada> _carregarDadosRelatorio({
    int? cicloPreferidoId,
  }) async {
    // Reinicia o estado da busca da nuvem a cada (re)carregamento.
    _leiturasNuvem = null;
    _cicloNuvemCarregadoId = null;
    _cicloNuvemEmProgresso = null;

    final dados = await _relatorioRepository.carregarRelatorio(
      widget.ipEstufa,
      cicloPreferidoId: cicloPreferidoId,
    );

    final ciclo = dados.cicloSelecionado;
    if (ciclo != null) {
      // Renderiza ja com o local (instantaneo) e busca a nuvem em segundo plano.
      unawaited(
        _carregarHistoricoNuvem(
          ciclo,
          ciclo.fim ?? DateTime.now(),
          dados.leituras,
        ),
      );
    }
    return dados;
  }

  Future<void> _carregarHistoricoNuvem(
    CicloSecagemEntity ciclo,
    DateTime fim,
    List<HistoricoLeituraEntity> locais,
  ) async {
    if (_cicloNuvemEmProgresso == ciclo.id ||
        _cicloNuvemCarregadoId == ciclo.id) {
      return;
    }
    _cicloNuvemEmProgresso = ciclo.id;

    final nuvem = (await _api.buscarHistorico(
      inicio: ciclo.inicio,
      fim: fim,
    )).map(_leituraDaNuvem).toList();

    if (!mounted) {
      _cicloNuvemEmProgresso = null;
      return;
    }
    setState(() {
      _leiturasNuvem = _mesclarHistoricos(locais, nuvem);
      _cicloNuvemCarregadoId = ciclo.id;
      _cicloNuvemEmProgresso = null;
    });
  }

  HistoricoLeituraEntity _leituraDaNuvem(Map<String, dynamic> m) {
    final temperatura = (m['temperaturaAtual'] as num?)?.toDouble() ?? 0;
    final umidade = (m['umidadeAtual'] as num?)?.toDouble() ?? 0;
    return HistoricoLeituraEntity()
      ..ipEstufa = widget.ipEstufa
      ..nomeEstufa = widget.nomeEstufa
      ..timestamp = DateTime.fromMillisecondsSinceEpoch(
        (m['timestampLeitura'] as num?)?.toInt() ?? 0,
      )
      ..temperatura = temperatura
      ..umidade = umidade
      // Leituras antigas da nuvem podem nao ter o ajuste: cai no proprio valor
      // para nao distorcer a cor e a linha de meta do grafico.
      ..temperaturaMeta =
          (m['temperaturaMeta'] as num?)?.toDouble() ?? temperatura
      ..umidadeMeta = (m['umidadeMeta'] as num?)?.toDouble() ?? umidade
      ..aviso = (m['aviso'] as String?) ?? ''
      ..alertaIncendio = m['alertaIncendio'] == true;
  }

  // Espacamento minimo entre pontos do grafico e o quanto o valor precisa mudar
  // para um ponto ser mantido mesmo perto do anterior.
  static const int _espacamentoMinGraficoMs = 5 * 60 * 1000;
  static const double _mudancaRelevanteGrafico = 5;

  // Une historico local e da nuvem, deduplicando por minuto (o local, gravado
  // com o ajuste real visto pelo app, vence em caso de empate), e afina os
  // pontos para o grafico nao ficar denso com fontes de cadencia diferente.
  List<HistoricoLeituraEntity> _mesclarHistoricos(
    List<HistoricoLeituraEntity> local,
    List<HistoricoLeituraEntity> nuvem,
  ) {
    final porMinuto = <int, HistoricoLeituraEntity>{};
    for (final leitura in [...nuvem, ...local]) {
      final chave = leitura.timestamp.millisecondsSinceEpoch ~/ 60000;
      porMinuto[chave] = leitura;
    }
    final ordenadas = porMinuto.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return _afinarPontos(ordenadas);
  }

  // Mantem o primeiro e o ultimo ponto e, no meio, so mantem um ponto se ja
  // passou o espacamento minimo desde o ultimo mantido OU se o valor mudou de
  // forma relevante (para nao perder mudancas reais). Deixa o grafico limpo
  // independente da cadencia das fontes.
  List<HistoricoLeituraEntity> _afinarPontos(
    List<HistoricoLeituraEntity> pontos,
  ) {
    if (pontos.length <= 2) return pontos;

    final resultado = <HistoricoLeituraEntity>[pontos.first];
    for (var i = 1; i < pontos.length; i++) {
      final atual = pontos[i];
      final ultimo = resultado.last;
      final ehUltimo = i == pontos.length - 1;
      final tempoDesde =
          atual.timestamp.millisecondsSinceEpoch -
          ultimo.timestamp.millisecondsSinceEpoch;
      final mudou =
          (atual.temperatura - ultimo.temperatura).abs() >=
              _mudancaRelevanteGrafico ||
          (atual.umidade - ultimo.umidade).abs() >= _mudancaRelevanteGrafico;

      final passouEspacamento = tempoDesde >= _espacamentoMinGraficoMs;
      if (ehUltimo && !passouEspacamento && !mudou && resultado.length > 1) {
        // O ponto final esta colado no ultimo mantido e sem mudanca relevante:
        // substitui em vez de criar um par colado no fim do grafico.
        resultado[resultado.length - 1] = atual;
      } else if (ehUltimo || passouEspacamento || mudou) {
        resultado.add(atual);
      }
    }
    return resultado;
  }



  void _adiarExibicaoGrafico() {
    if (_mostrarGrafico || _timerGrafico != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mostrarGrafico || _timerGrafico != null) return;

      _timerGrafico = Timer(const Duration(milliseconds: 120), () {
        _timerGrafico = null;
        if (mounted) {
          setState(() => _mostrarGrafico = true);
        }
      });
    });
  }

  void _resetarExibicaoGrafico() {
    _timerGrafico?.cancel();
    _timerGrafico = null;
    _mostrarGrafico = false;
  }

  void _alterarTipoGrafico(bool graficoTemperatura) {
    setState(() {
      _graficoTemperatura = graficoTemperatura;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        leading: IconButton(
          iconSize: 20,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'RELAT\u00D3RIOS DAS ESTUFADAS',
            maxLines: 1,
            softWrap: false,
          ),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            iconSize: 22,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.download, color: Colors.white70),
            tooltip: 'Baixar relatório',
            color: const Color(0xFF252830),
            onSelected: (valor) {
              if (valor == 'pdf') {
                _exportarPdf();
              } else if (valor == 'csv') {
                _exportarCsv();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('Baixar PDF'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('Baixar CSV (dados)'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: _cicloSelecionadoId == null
                ? null
                : _apagarCicloSelecionado,
            tooltip: 'Apagar esta estufada',
          ),
          // Sem botao de atualizar: quem atualiza e o puxar-para-atualizar,
          // como no monitoramento. Manter os dois deixava a barra apertada
          // (titulo longo + tres icones) para uma acao ja coberta pelo gesto.
        ],
      ),
      // Puxar para atualizar, como no monitoramento: o gesto e o mesmo em todo
      // o app.
      // O SafeArea evita que o conteudo passe POR BAIXO da barra do sistema:
      // fica so meio encoberto, mas o que cair ali no fim da pagina nao aceita
      // toque - o gesto pertence ao sistema, nao ao app.
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _recarregarRelatorio,
          color: Colors.white,
          backgroundColor: const Color(0xFF1C1C1E),
          child: FutureBuilder<DadosRelatorioEstufada>(
            future: _dadosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final dados = snapshot.data ?? DadosRelatorioEstufada.vazio();
              _ciclos = dados.ciclos;
              _recalcularPosicoes();
              _eventos = dados.eventos;
              final cicloSelecionado = dados.cicloSelecionado;
              _cicloSelecionadoId = cicloSelecionado?.id;
              // Usa o histórico mesclado com a nuvem quando já disponível para este
              // ciclo; senão, o local (renderiza na hora e completa em seguida).
              _leiturasBrutas =
                  (_cicloNuvemCarregadoId == cicloSelecionado?.id &&
                      _leiturasNuvem != null)
                  ? _leiturasNuvem!
                  : dados.leituras;
              final leituras = _aplicarFiltro(_leiturasBrutas);

              if (_leiturasBrutas.isEmpty) {
                return SingleChildScrollView(
                  // Sempre rolavel (nos tres estados desta tela), para o
                  // puxar-para-atualizar funcionar tambem quando o conteudo cabe
                  // inteiro - que e justamente o caso da tela sem dados.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSeletorEstufada(),
                      const SizedBox(height: 28),
                      const Text(
                        'Sem dados hist\u00F3ricos ainda. Inicie uma estufada para registrar as leituras do ciclo.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              if (leituras.isEmpty) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSeletorEstufada(),
                      const SizedBox(height: 28),
                      const Text(
                        'Nenhum dado no per\u00EDodo selecionado.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final duracao = duracaoDaEstufada(
                inicioDoCiclo: cicloSelecionado?.inicio,
                fimDoCiclo: cicloSelecionado?.fim,
                intervaloDasLeituras: leituras.last.timestamp.difference(
                  leituras.first.timestamp,
                ),
              );
              final primeiraLeitura = leituras.first;
              final ultimaLeitura = leituras.last;
              final temperaturaAjusteInicial = primeiraLeitura.temperaturaMeta;
              final temperaturaAjusteFinal = ultimaLeitura.temperaturaMeta;
              final umidadeAjusteInicial = primeiraLeitura.umidadeMeta;
              final umidadeAjusteFinal = ultimaLeitura.umidadeMeta;
              // Conta EPISODIOS, e nao leituras.
              //
              // Antes era `leituras.where((e) => e.alertaIncendio)`, o que dava
              // o numero de LEITURAS gravadas com a sirene ligada — o campo,
              // apesar do nome, guarda `alarmeAtivo`, que e temperatura ou fogo.
              // "ALARMES: 17" nao eram 17 alarmes: era duracao disfarcada de
              // contagem, numa unidade que ninguem adivinha (leituras, cuja
              // cadencia depende de afinamento e de fonte).
              //
              // Os eventos ja registram a BORDA — `alarme_processo` e
              // `alerta_incendio` nascem quando a sirene liga, uma vez por
              // episodio. E o numero passa a bater com o que o produtor consegue
              // contar a mao na lista logo abaixo, que e a unica conferencia que
              // ele tem.
              //
              // Oscilacao NAO entra: ela e desvio detectado pelo app, e a sirene
              // tem margem e janela de acomodacao. Uma estufada pode ter varias
              // oscilacoes e nenhum alarme — e ai zero e a resposta certa.
              final totalAlarmes = _aplicarFiltroEventos(_eventos)
                  .where(
                    (e) =>
                        e.tipo == 'alarme_processo' ||
                        e.tipo == 'alerta_incendio',
                  )
                  .length;
              _adiarExibicaoGrafico();

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSeletorEstufada(),
                    const SizedBox(height: 20),
                    ResumoEstufadaCard(
                      duracao: duracao,
                      temperaturaAjusteInicial: temperaturaAjusteInicial,
                      temperaturaAjusteFinal: temperaturaAjusteFinal,
                      umidadeAjusteInicial: umidadeAjusteInicial,
                      umidadeAjusteFinal: umidadeAjusteFinal,
                      totalAlarmes: totalAlarmes,
                      tituloSecaoStyle: _tituloSecaoStyle,
                      filtroAtivo:
                          _inicioFiltro != null || _fimFiltro != null,
                    ),
                    const SizedBox(height: 18),

                    if (cicloSelecionado != null) ...[
                      EventosEstufadaCard(
                        cicloSelecionado: cicloSelecionado,
                        eventos: _aplicarFiltroEventos(_eventos),
                        filtroAtivo:
                            _inicioFiltro != null || _fimFiltro != null,
                        tituloSecaoStyle: _tituloSecaoStyle,
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 6),
                    _mostrarGrafico
                        ? GraficoEstufadaCard(
                            leituras: leituras,
                            graficoTemperatura: _graficoTemperatura,
                            tituloSecaoStyle: _tituloSecaoStyle,
                            onGraficoChanged: _alterarTipoGrafico,
                            filtroAtivo:
                                _inicioFiltro != null || _fimFiltro != null,
                          )
                        : GraficoEstufadaLoadingCard(
                            graficoTemperatura: _graficoTemperatura,
                            tituloSecaoStyle: _tituloSecaoStyle,
                            onGraficoChanged: _alterarTipoGrafico,
                          ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSeletorEstufada() {
    return SeletorEstufadaPeriodoCard(
      ciclos: _ciclos,
      cicloSelecionadoId: _cicloSelecionadoId,
      inicioFiltro: _inicioFiltro,
      fimFiltro: _fimFiltro,
      tituloSecaoStyle: _tituloSecaoStyle,
      onCicloChanged: _selecionarCiclo,
      onSelecionarInicio: _selecionarInicio,
      onSelecionarFim: _selecionarFim,
      onLimparFiltro: _limparFiltro,
      rotuloCiclo: _rotuloCiclo,
    );
  }

  void _selecionarCiclo(int cicloId) {
    setState(() {
      _resetarExibicaoGrafico();
      _cicloSelecionadoId = cicloId;
      _inicioFiltro = null;
      _fimFiltro = null;
      _dadosFuture = _carregarDadosRelatorio(cicloPreferidoId: cicloId);
    });
  }

  Future<void> _apagarCicloSelecionado() async {
    final id = _cicloSelecionadoId;
    if (id == null) return;
    CicloSecagemEntity? ciclo;
    for (final c in _ciclos) {
      if (c.id == id) {
        ciclo = c;
        break;
      }
    }
    if (ciclo == null) return;
    final rotulo = _rotuloCiclo(ciclo);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252830),
        title: const Text(
          'Apagar estufada?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Estufada $rotulo\n\nIsto remove o relatório, os eventos e as '
          'leituras deste ciclo. Não dá para desfazer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Apagar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _relatorioRepository.apagarCiclo(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Estufada apagada.')));
    setState(() {
      _resetarExibicaoGrafico();
      _cicloSelecionadoId = null;
      _dadosFuture = _carregarDadosRelatorio();
    });
  }

  Future<void> _selecionarInicio() async {
    final selecionado = await _selecionarDataHora(
      valorAtual: _inicioFiltro,
      referencia: _fimFiltro,
      horaPadrao: const TimeOfDay(hour: 0, minute: 0),
    );
    if (selecionado == null) return;

    final novoFim = _fimFiltro;
    if (!_filtroPeriodoValido(inicio: selecionado, fim: novoFim)) return;

    setState(() => _inicioFiltro = selecionado);
  }

  Future<void> _selecionarFim() async {
    final selecionado = await _selecionarDataHora(
      valorAtual: _fimFiltro,
      referencia: _inicioFiltro,
      horaPadrao: const TimeOfDay(hour: 23, minute: 59),
    );
    if (selecionado == null) return;

    final novoInicio = _inicioFiltro;
    if (!_filtroPeriodoValido(inicio: novoInicio, fim: selecionado)) return;

    setState(() => _fimFiltro = selecionado);
  }

  Future<DateTime?> _selecionarDataHora({
    required DateTime? valorAtual,
    required DateTime? referencia,
    required TimeOfDay horaPadrao,
  }) async {
    final base = valorAtual ?? referencia ?? DateTime.now();
    final dataSelecionada = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (dataSelecionada == null || !mounted) return null;

    final horaInicial = valorAtual == null
        ? horaPadrao
        : TimeOfDay(hour: valorAtual.hour, minute: valorAtual.minute);
    final horaSelecionada = await showTimePicker(
      context: context,
      initialTime: horaInicial,
    );
    if (horaSelecionada == null) return null;

    return DateTime(
      dataSelecionada.year,
      dataSelecionada.month,
      dataSelecionada.day,
      horaSelecionada.hour,
      horaSelecionada.minute,
    );
  }

  void _limparFiltro() {
    setState(() {
      _inicioFiltro = null;
      _fimFiltro = null;
    });
  }

  bool _filtroPeriodoValido({DateTime? inicio, DateTime? fim}) {
    if (inicio == null || fim == null) return true;

    if (fim.isBefore(inicio)) {
      _mostrarAvisoFiltro('O fim do filtro precisa ser depois do in\u00EDcio.');
      return false;
    }

    if (fim.difference(inicio) < _intervaloMinimoFiltro) {
      _mostrarAvisoFiltro(
        'Escolha um intervalo de pelo menos 1 hora para filtrar o relat\u00F3rio.',
      );
      return false;
    }

    return true;
  }

  void _mostrarAvisoFiltro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  List<HistoricoLeituraEntity> _aplicarFiltro(
    List<HistoricoLeituraEntity> leituras,
  ) {
    var filtradas = leituras;
    final ciclo = _cicloSelecionado();

    if (ciclo != null) {
      final fimCiclo = ciclo.fim ?? DateTime.now();
      filtradas = filtradas
          .where(
            (e) =>
                !e.timestamp.isBefore(ciclo.inicio) &&
                !e.timestamp.isAfter(fimCiclo),
          )
          .toList();
    }

    if (_inicioFiltro != null) {
      filtradas = filtradas
          .where((e) => !e.timestamp.isBefore(_inicioFiltro!))
          .toList();
    }

    if (_fimFiltro != null) {
      final fimInclusivo = DateTime(
        _fimFiltro!.year,
        _fimFiltro!.month,
        _fimFiltro!.day,
        _fimFiltro!.hour,
        _fimFiltro!.minute,
        59,
        999,
      );
      filtradas = filtradas
          .where((e) => !e.timestamp.isAfter(fimInclusivo))
          .toList();
    }

    return filtradas;
  }

  CicloSecagemEntity? _cicloSelecionado() {
    if (_cicloSelecionadoId == null) return null;
    for (final ciclo in _ciclos) {
      if (ciclo.id == _cicloSelecionadoId) return ciclo;
    }
    return null;
  }

  // Reordena as estufadas por data de inicio (mais antiga = 1) e guarda a
  // posicao de cada uma. Assim o numero exibido acompanha a ordem cronologica
  // e nunca fica com buraco, mesmo depois de apagar uma estufada.
  void _recalcularPosicoes() {
    final ordenados = [..._ciclos]
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    _posicaoPorCiclo.clear();
    for (var i = 0; i < ordenados.length; i++) {
      _posicaoPorCiclo[ordenados[i].id] = i + 1;
    }
  }

  String _rotuloCiclo(CicloSecagemEntity ciclo) {
    final inicio = DateFormat('dd/MM HH:mm').format(ciclo.inicio);
    final fim = ciclo.fim == null
        ? 'em andamento'
        : DateFormat('dd/MM HH:mm').format(ciclo.fim!);
    final posicao = _posicaoPorCiclo[ciclo.id] ?? _ciclos.length;
    return '$posicao | $inicio - $fim';
  }

  Future<void> _exportarPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final leiturasFiltradas = _aplicarFiltro(_leiturasBrutas);

    if (leiturasFiltradas.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sem dados para gerar o relatório.')),
      );
      return;
    }

    CicloSecagemEntity? cicloSelecionado;
    for (final ciclo in _ciclos) {
      if (ciclo.id == _cicloSelecionadoId) {
        cicloSelecionado = ciclo;
        break;
      }
    }
    final eventosFiltrados = _aplicarFiltroEventos(_eventos);
    final nomeArquivo = _csvService.nomeArquivo(
      widget.nomeEstufa,
      leiturasFiltradas,
    );

    try {
      final pdf = await _pdfService.gerarPdf(
        nomeEstufa: widget.nomeEstufa,
        ciclo: cicloSelecionado,
        leituras: leiturasFiltradas,
        eventos: eventosFiltrados,
      );
      await Printing.sharePdf(bytes: pdf, filename: '$nomeArquivo.pdf');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Falha ao gerar o PDF: $e')),
      );
    }
  }

  Future<void> _exportarCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    final leiturasFiltradas = _aplicarFiltro(_leiturasBrutas);

    if (leiturasFiltradas.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sem dados para exportar.')),
      );
      return;
    }

    final csv = _csvService.montarCsv(leiturasFiltradas);
    final fileName = _csvService.nomeArquivo(
      widget.nomeEstufa,
      leiturasFiltradas,
    );

    try {
      final destino = await exportCsvFile(fileName: fileName, csvContent: csv);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('CSV exportado: $destino')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Falha ao exportar CSV: $e')),
      );
    }
  }

  List<EventoCicloEntity> _aplicarFiltroEventos(
    List<EventoCicloEntity> eventos,
  ) {
    // Umidade fora do ajuste nao e evento de relatorio: numa estufa de secagem
    // ficar muito abaixo e o objetivo do processo, e a linha se repetia a
    // estufada inteira, empurrando para fora da tela o que diz alguma coisa. O
    // app parou de gravar essas linhas em 11/08/2026 — o filtro aqui e para as
    // estufadas que ja tinham as suas guardadas.
    var filtrados = eventos
        .where((e) => !e.tipo.startsWith('oscilacao_umidade'))
        .toList();

    if (_inicioFiltro != null) {
      filtrados = filtrados
          .where((e) => !e.timestamp.isBefore(_inicioFiltro!))
          .toList();
    }

    if (_fimFiltro != null) {
      final fimInclusivo = DateTime(
        _fimFiltro!.year,
        _fimFiltro!.month,
        _fimFiltro!.day,
        _fimFiltro!.hour,
        _fimFiltro!.minute,
        59,
        999,
      );
      filtrados = filtrados
          .where((e) => !e.timestamp.isAfter(fimInclusivo))
          .toList();
    }

    return filtrados;
  }
}

