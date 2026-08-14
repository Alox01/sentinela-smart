import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/historico_leitura_entity.dart';
import '../../../widgets/grafico_steam.dart';

class GraficoEstufadaCard extends StatelessWidget {
  final List<HistoricoLeituraEntity> leituras;
  final bool graficoTemperatura;
  final TextStyle tituloSecaoStyle;
  final ValueChanged<bool> onGraficoChanged;

  /// Com filtro, quem manda no periodo e o produtor: o grafico mostra o que ele
  /// pediu, do comeco ao fim. Sem filtro, abre nas ultimas [_janelaSemFiltro].
  final bool filtroAtivo;

  const GraficoEstufadaCard({
    super.key,
    required this.leituras,
    required this.graficoTemperatura,
    required this.tituloSecaoStyle,
    required this.onGraficoChanged,
    this.filtroAtivo = false,
  });

  /// Quanto tempo o grafico mostra quando ninguem filtrou nada.
  ///
  /// Uma secagem passa de 100h. Desenhar tudo de uma vez e o que amassava o
  /// cartao: ou a largura crescia sem fim, ou um teto espremia a estufada
  /// inteira num punhado de pixels. Um dia e o que cabe sendo legivel, e o resto
  /// continua a um filtro de distancia — nada e apagado.
  static const Duration _janelaSemFiltro = Duration(hours: 24);

  /// Quanto tempo cabe em uma tela. Fixo de proposito: uma hora de secagem ocupa
  /// o mesmo espaco tenha a estufada 3h ou 100h, e o grafico deixa de apertar
  /// conforme a secagem cresce.
  static const double _horasPorTela = 2;

  /// Recorta na janela padrao, ancorando no ULTIMO DADO e nunca no relogio.
  ///
  /// Ancorar em "agora" ja custou caro aqui: relatorio de estufada encerrada
  /// abria vazio, porque a janela parava num intervalo sem leitura nenhuma —
  /// moldura, eixos e botoes, sem linha. O fim da estufada e o fim da janela.
  ({List<HistoricoLeituraEntity> visiveis, bool recortou}) _janela(
    List<HistoricoLeituraEntity> ordenadas,
  ) {
    if (filtroAtivo || ordenadas.length < 2) {
      return (visiveis: ordenadas, recortou: false);
    }

    final corte = ordenadas.last.timestamp.subtract(_janelaSemFiltro);
    if (!ordenadas.first.timestamp.isBefore(corte)) {
      return (visiveis: ordenadas, recortou: false);
    }

    return (
      visiveis: ordenadas
          .where((leitura) => !leitura.timestamp.isBefore(corte))
          .toList(),
      recortou: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ordena por horario para a linha nunca "voltar no tempo" e para manter
    // leitura, ajuste e cor alinhados pelo mesmo indice.
    final todas = [...leituras]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final janela = _janela(todas);
    final leiturasOrdenadas = janela.visiveis;
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
      recortadoNaJanelaPadrao: janela.recortou,
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
            ),
          );

          if (!telaEstreita) return grafico;

          return _GraficoRolavelMobile(
            largura: _larguraGraficoMobile(
              constraints.maxWidth,
              leiturasOrdenadas,
            ),
            child: grafico,
          );
        },
      ),
    );
  }

  /// Largura interna do grafico, que o arraste horizontal percorre.
  ///
  /// Densidade fixa: [_horasPorTela] de secagem por tela, sempre. Antes a conta
  /// pedia 120px a cada 10 minutos e terminava num teto de 1800px — uma estufada
  /// de 26h pedia 18.840px e recebia 1.800, dez vezes mais apertada do que a
  /// propria conta mandava. Amarrando a densidade a largura da tela, o aperto
  /// deixa de existir: o que cresce com a secagem e o quanto se arrasta, nao o
  /// quanto se espreme.
  ///
  /// Sem filtro isso da ~12 telas, porque a janela e de um dia. Com filtro da o
  /// que o produtor pediu — foi escolha dele.
  double _larguraGraficoMobile(
    double larguraDisponivel,
    List<HistoricoLeituraEntity> visiveis,
  ) {
    if (visiveis.length < 2 || larguraDisponivel <= 0) {
      return math.max(larguraDisponivel, 760);
    }

    final horas =
        visiveis.last.timestamp.difference(visiveis.first.timestamp).inMinutes /
        60;
    final larguraPorHora = larguraDisponivel / _horasPorTela;

    return math.max(larguraDisponivel, horas * larguraPorHora);
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
  final bool recortadoNaJanelaPadrao;

  const _MolduraGrafico({
    required this.tituloSecaoStyle,
    required this.graficoTemperatura,
    required this.onGraficoChanged,
    required this.child,
    this.altura,
    this.recortadoNaJanelaPadrao = false,
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
          if (recortadoNaJanelaPadrao) ...[
            const SizedBox(height: 6),
            const _AvisoJanelaPadrao(),
          ],
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
          const _LegendaDoGrafico(),
          const SizedBox(height: 6),
          const _DicaRolagemGrafico(),
        ],
      );
    }

    return Column(
      children: [
        Row(
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
        ),
        const SizedBox(height: 6),
        // A legenda vale nos dois tamanhos: a duvida sobre o tracejado nao
        // depende da largura da tela.
        const _LegendaDoGrafico(),
      ],
    );
  }
}

/// Diz que o grafico nao esta mostrando a secagem inteira.
///
/// Sem isto o recorte seria silencioso, e quem abrisse o relatorio de uma
/// secagem de quatro dias concluiria que ela durou um. Um recorte que se anuncia
/// e escolha informada; um recorte calado e informacao errada.
class _AvisoJanelaPadrao extends StatelessWidget {
  const _AvisoJanelaPadrao();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: Colors.white38),
        SizedBox(width: 6),
        // Curta o bastante para caber em uma linha: quebrando em duas, o icone
        // saia do eixo das outras duas legendas e a pilha inteira ficava torta.
        // Como chegar ao resto e o filtro, que esta logo acima nesta tela.
        Flexible(
          child: Text(
            'Mostrando as últimas 24h',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Diz o que e a linha tracejada.
///
/// Sem isto, o cinza pontilhado ao lado da leitura nao se explica: quem nao
/// construiu o app nao tem como saber que aquilo e o ajuste, e um gráfico com
/// duas linhas sem legenda convida a interpretar a errada. O balao de toque ja
/// mostrava "Leitura" e "Ajuste", mas so depois de tocar — e ninguem toca no que
/// nao entende.
class _LegendaDoGrafico extends StatelessWidget {
  const _LegendaDoGrafico();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Dois tracinhos, e nao uma linha inteira: o simbolo tem de PARECER o
        // que esta no grafico, senao a legenda vira mais uma coisa a decifrar.
        for (var i = 0; i < 2; i++) ...[
          Container(width: 7, height: 1.5, color: Colors.white38),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 3),
        // Flexivel porque em tela de 360dp a frase nao cabe na linha e o Row
        // estourava — em release nao aparece listra nenhuma, o texto so era
        // cortado calado.
        const Flexible(
          child: Text(
            'linha tracejada = ajuste programado',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
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
        Flexible(
          child: Text(
            'Arraste para ver mais horários',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
