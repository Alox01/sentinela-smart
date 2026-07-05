import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/historico_leitura_entity.dart';
import '../../../widgets/grafico_steam.dart';

class GraficoEstufadaCard extends StatelessWidget {
  final List<HistoricoLeituraEntity> leituras;
  final bool graficoTemperatura;
  final bool filtroAtivo;
  final TextStyle tituloSecaoStyle;
  final ValueChanged<bool> onGraficoChanged;

  const GraficoEstufadaCard({
    super.key,
    required this.leituras,
    required this.graficoTemperatura,
    required this.filtroAtivo,
    required this.tituloSecaoStyle,
    required this.onGraficoChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Ordena por horario para a linha nunca "voltar no tempo" e para manter
    // leitura, ajuste e cor alinhados pelo mesmo indice.
    final leiturasOrdenadas = [...leituras]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final pontosGraficoTemperatura = leiturasOrdenadas
        .map(
          (leitura) => FlSpot(
            leitura.timestamp.millisecondsSinceEpoch.toDouble(),
            leitura.temperatura,
          ),
        )
        .toList();
    final pontosGraficoUmidade = leiturasOrdenadas
        .map(
          (leitura) => FlSpot(
            leitura.timestamp.millisecondsSinceEpoch.toDouble(),
            leitura.umidade,
          ),
        )
        .toList();
    final ajustesTemperaturaGrafico = leiturasOrdenadas
        .map((e) => e.temperaturaMeta)
        .toList();
    final ajustesUmidadeGrafico = leiturasOrdenadas
        .map((e) => e.umidadeMeta)
        .toList();
    final pontosGrafico = graficoTemperatura
        ? pontosGraficoTemperatura
        : pontosGraficoUmidade;
    final ajustesGrafico = graficoTemperatura
        ? ajustesTemperaturaGrafico
        : ajustesUmidadeGrafico;
    final corGrafico = graficoTemperatura
        ? Colors.orange
        : Colors.lightBlueAccent;
    final unidadeGrafico = graficoTemperatura ? '°F' : '%';
    final coresHistoricas = leiturasOrdenadas
        .map(
          (e) => _corPontoGrafico(
            atual: graficoTemperatura ? e.temperatura : e.umidade,
            ajuste: graficoTemperatura ? e.temperaturaMeta : e.umidadeMeta,
          ),
        )
        .toList();
    final minYGrafico = graficoTemperatura ? 60.0 : 0.0;
    final maxYGrafico = graficoTemperatura ? 205.0 : 105.0;
    final intervaloYGrafico = graficoTemperatura ? 35.0 : 25.0;
    final rotulosYGrafico = graficoTemperatura
        ? const [60, 95, 130, 165, 200]
        : const [0, 25, 50, 75, 100];

    return _MolduraGrafico(
      tituloSecaoStyle: tituloSecaoStyle,
      graficoTemperatura: graficoTemperatura,
      onGraficoChanged: onGraficoChanged,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final telaEstreita = MediaQuery.sizeOf(context).width < 430;
          final alturaGrafico = telaEstreita ? 360.0 : 320.0;
          final grafico = SizedBox(
            height: alturaGrafico,
            child: GraficoSteam(
              pontos: pontosGrafico,
              ajustes: ajustesGrafico,
              coresHistoricas: coresHistoricas,
              corAtual: corGrafico,
              unidade: unidadeGrafico,
              minY: minYGrafico,
              maxY: maxYGrafico,
              intervaloY: intervaloYGrafico,
              rotulosY: rotulosYGrafico,
              filtroAtivo: filtroAtivo,
            ),
          );

          if (!telaEstreita) return grafico;

          final larguraInterna = math.max(
            constraints.maxWidth,
            _larguraGraficoMobile(),
          );
          return _GraficoRolavelMobile(largura: larguraInterna, child: grafico);
        },
      ),
    );
  }

  double _larguraGraficoMobile() {
    if (leituras.length < 2) return 760;

    final inicio = leituras.first.timestamp;
    final fim = leituras.last.timestamp;
    final minutos = fim.difference(inicio).inMinutes.abs();
    final janelaMinutos = math.max(60, minutos + 10);
    final blocosDezMinutos = (janelaMinutos / 10).ceil();
    final largura = 120.0 * blocosDezMinutos;

    return largura.clamp(760.0, 1800.0);
  }

  Color _corPontoGrafico({required double atual, required double ajuste}) {
    final diferenca = atual - ajuste;
    const tolerancia = 5.0;

    if (graficoTemperatura) {
      if (diferenca > tolerancia) return Colors.redAccent;
      if (diferenca < -tolerancia) return Colors.amberAccent;
      return Colors.orange;
    }

    if (diferenca > tolerancia) return Colors.blueAccent;
    if (diferenca < -tolerancia) return Colors.cyanAccent;
    return Colors.lightBlueAccent;
  }
}

class _GraficoRolavelMobile extends StatefulWidget {
  final double largura;
  final Widget child;

  const _GraficoRolavelMobile({required this.largura, required this.child});

  @override
  State<_GraficoRolavelMobile> createState() => _GraficoRolavelMobileState();
}

class _GraficoRolavelMobileState extends State<_GraficoRolavelMobile> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 4,
      radius: const Radius.circular(999),
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SizedBox(width: widget.largura, child: widget.child),
        ),
      ),
    );
  }
}

class GraficoEstufadaLoadingCard extends StatelessWidget {
  final bool graficoTemperatura;
  final TextStyle tituloSecaoStyle;
  final ValueChanged<bool> onGraficoChanged;

  const GraficoEstufadaLoadingCard({
    super.key,
    required this.graficoTemperatura,
    required this.tituloSecaoStyle,
    required this.onGraficoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _MolduraGrafico(
      tituloSecaoStyle: tituloSecaoStyle,
      graficoTemperatura: graficoTemperatura,
      onGraficoChanged: onGraficoChanged,
      altura: 380,
      child: const Expanded(
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _MolduraGrafico extends StatelessWidget {
  final TextStyle tituloSecaoStyle;
  final bool graficoTemperatura;
  final ValueChanged<bool> onGraficoChanged;
  final Widget child;
  final double? altura;

  const _MolduraGrafico({
    required this.tituloSecaoStyle,
    required this.graficoTemperatura,
    required this.onGraficoChanged,
    required this.child,
    this.altura,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 430 ? 14 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _CabecalhoGrafico(
            graficoTemperatura: graficoTemperatura,
            tituloSecaoStyle: tituloSecaoStyle,
            onGraficoChanged: onGraficoChanged,
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CabecalhoGrafico extends StatelessWidget {
  final bool graficoTemperatura;
  final TextStyle tituloSecaoStyle;
  final ValueChanged<bool> onGraficoChanged;

  const _CabecalhoGrafico({
    required this.graficoTemperatura,
    required this.tituloSecaoStyle,
    required this.onGraficoChanged,
  });

  @override
  Widget build(BuildContext context) {
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;
    final seletor = SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: true,
          icon: Icon(Icons.thermostat, size: 16),
          label: Text('Temperatura'),
        ),
        ButtonSegment<bool>(
          value: false,
          icon: Icon(Icons.water_drop, size: 16),
          label: Text('Umidade'),
        ),
      ],
      selected: {graficoTemperatura},
      onSelectionChanged: (selecionado) {
        onGraficoChanged(selecionado.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return graficoTemperatura
                ? Colors.orangeAccent
                : Colors.lightBlueAccent;
          }
          return Colors.white60;
        }),
      ),
    );

    if (telaEstreita) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'GRÁFICO DA ESTUFADA',
            style: tituloSecaoStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Center(child: seletor),
          const SizedBox(height: 8),
          const _DicaRolagemGrafico(),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'GRÁFICO DA ESTUFADA',
            style: tituloSecaoStyle,
            textAlign: TextAlign.center,
          ),
        ),
        seletor,
      ],
    );
  }
}

class _DicaRolagemGrafico extends StatelessWidget {
  const _DicaRolagemGrafico();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.white38),
        SizedBox(width: 6),
        Text(
          'Arraste para ver mais horários',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
