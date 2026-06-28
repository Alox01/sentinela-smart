import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ciclo_secagem_entity.dart';
import '../models/evento_ciclo_entity.dart';
import '../models/historico_leitura_entity.dart';
import '../features/relatorio_estufada/services/relatorio_estufada_repository.dart';
import '../features/relatorio_estufada/widgets/grafico_estufada_card.dart';
import '../features/relatorio_estufada/services/relatorio_csv_service.dart';
import '../services/csv_exporter.dart';
import '../services/isar_service.dart';
import '../features/relatorio_estufada/widgets/eventos_estufada_card.dart';
import '../features/relatorio_estufada/widgets/resumo_estufada_card.dart';
import '../features/relatorio_estufada/widgets/seletor_estufada_periodo_card.dart';

class HistoricoScreen extends StatefulWidget {
  final String nomeEstufa;
  final String ipEstufa;

  const HistoricoScreen({
    super.key,
    required this.nomeEstufa,
    required this.ipEstufa,
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
  final RelatorioEstufadaRepository _relatorioRepository =
      RelatorioEstufadaRepository(IsarService.instance);

  late Future<_DadosRelatorioEstufada> _dadosFuture;
  List<HistoricoLeituraEntity> _leiturasBrutas = [];
  List<CicloSecagemEntity> _ciclos = [];
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
    _dadosFuture = _carregarDadosRelatorio();
  }

  @override
  void dispose() {
    _timerGrafico?.cancel();
    super.dispose();
  }

  Future<_DadosRelatorioEstufada> _carregarDadosRelatorio({
    int? cicloPreferidoId,
  }) async {
    final ciclos = await _relatorioRepository.listarCiclosPorIp(
      widget.ipEstufa,
    );
    final cicloSelecionado = _escolherCicloInicial(ciclos, cicloPreferidoId);

    if (cicloSelecionado == null) {
      return _DadosRelatorioEstufada(
        leituras: const [],
        ciclos: ciclos,
        eventos: const [],
        cicloSelecionado: null,
      );
    }

    final fimCiclo = cicloSelecionado.fim ?? DateTime.now();
    final resultados = await Future.wait([
      _relatorioRepository.listarHistoricoPorIpNoPeriodo(
        widget.ipEstufa,
        inicio: cicloSelecionado.inicio,
        fim: fimCiclo,
      ),
      _relatorioRepository.listarEventosPorCiclo(cicloSelecionado.id),
    ]);

    return _DadosRelatorioEstufada(
      leituras: resultados[0] as List<HistoricoLeituraEntity>,
      ciclos: ciclos,
      eventos: resultados[1] as List<EventoCicloEntity>,
      cicloSelecionado: cicloSelecionado,
    );
  }

  CicloSecagemEntity? _escolherCicloInicial(
    List<CicloSecagemEntity> ciclos,
    int? cicloPreferidoId,
  ) {
    if (ciclos.isEmpty) return null;

    if (cicloPreferidoId != null) {
      for (final ciclo in ciclos) {
        if (ciclo.id == cicloPreferidoId) return ciclo;
      }
    }

    for (final ciclo in ciclos) {
      if (ciclo.status == 'em_andamento') return ciclo;
    }

    return ciclos.first;
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
          IconButton(
            icon: const Icon(Icons.download, color: Colors.greenAccent),
            onPressed: _exportarCsv,
            tooltip: 'Exportar CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: () {
              setState(() {
                _resetarExibicaoGrafico();
                _cicloSelecionadoId = null;
                _dadosFuture = _carregarDadosRelatorio();
              });
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<_DadosRelatorioEstufada>(
        future: _dadosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final dados = snapshot.data ?? _DadosRelatorioEstufada.vazio();
          _leiturasBrutas = dados.leituras;
          _ciclos = dados.ciclos;
          _eventos = dados.eventos;
          final cicloSelecionado = dados.cicloSelecionado;
          _cicloSelecionadoId = cicloSelecionado?.id;
          final leituras = _aplicarFiltro(_leiturasBrutas);

          if (_leiturasBrutas.isEmpty) {
            return SingleChildScrollView(
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

          final inicio = leituras.first.timestamp;
          final fim = leituras.last.timestamp;
          final duracao = fim.difference(inicio);
          final primeiraLeitura = leituras.first;
          final ultimaLeitura = leituras.last;
          final temperaturaMetaInicial = primeiraLeitura.temperaturaMeta;
          final temperaturaMetaFinal = ultimaLeitura.temperaturaMeta;
          final umidadeMetaInicial = primeiraLeitura.umidadeMeta;
          final umidadeMetaFinal = ultimaLeitura.umidadeMeta;
          final totalAlarmes = leituras.where((e) => e.alertaIncendio).length;
          _adiarExibicaoGrafico();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSeletorEstufada(),
                const SizedBox(height: 20),
                ResumoEstufadaCard(
                  duracao: duracao,
                  temperaturaMetaInicial: temperaturaMetaInicial,
                  temperaturaMetaFinal: temperaturaMetaFinal,
                  umidadeMetaInicial: umidadeMetaInicial,
                  umidadeMetaFinal: umidadeMetaFinal,
                  totalAlarmes: totalAlarmes,
                  tituloSecaoStyle: _tituloSecaoStyle,
                ),
                const SizedBox(height: 18),

                if (cicloSelecionado != null) ...[
                  EventosEstufadaCard(
                    cicloSelecionado: cicloSelecionado,
                    eventos: _aplicarFiltroEventos(_eventos),
                    filtroAtivo: _inicioFiltro != null || _fimFiltro != null,
                    tituloSecaoStyle: _tituloSecaoStyle,
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 6),
                _mostrarGrafico
                    ? GraficoEstufadaCard(
                        leituras: leituras,
                        graficoTemperatura: _graficoTemperatura,
                        filtroAtivo:
                            _inicioFiltro != null || _fimFiltro != null,
                        tituloSecaoStyle: _tituloSecaoStyle,
                        onGraficoChanged: _alterarTipoGrafico,
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

  String _rotuloCiclo(CicloSecagemEntity ciclo) {
    final inicio = DateFormat('dd/MM HH:mm').format(ciclo.inicio);
    final fim = ciclo.fim == null
        ? 'em andamento'
        : DateFormat('dd/MM HH:mm').format(ciclo.fim!);
    return '#${ciclo.id} | $inicio - $fim';
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
    var filtrados = eventos;

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

class _DadosRelatorioEstufada {
  final List<HistoricoLeituraEntity> leituras;
  final List<CicloSecagemEntity> ciclos;
  final List<EventoCicloEntity> eventos;
  final CicloSecagemEntity? cicloSelecionado;

  const _DadosRelatorioEstufada({
    required this.leituras,
    required this.ciclos,
    required this.eventos,
    required this.cicloSelecionado,
  });

  factory _DadosRelatorioEstufada.vazio() {
    return const _DadosRelatorioEstufada(
      leituras: [],
      ciclos: [],
      eventos: [],
      cicloSelecionado: null,
    );
  }
}
