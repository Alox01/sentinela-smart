import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GraficoSteam extends StatelessWidget {
  final List<FlSpot> pontos;
  final List<double> ajustes;
  final List<Color> coresHistoricas;
  final Color corAtual;
  final String unidade;
  final double minY;
  final double maxY;
  final double intervaloY;
  final List<int> rotulosY;
  final bool filtroAtivo;

  const GraficoSteam({
    super.key,
    required this.pontos,
    this.ajustes = const [],
    required this.coresHistoricas,
    required this.corAtual,
    this.unidade = '\u00B0F',
    this.minY = 60,
    this.maxY = 205,
    this.intervaloY = 35,
    this.rotulosY = const [60, 95, 130, 165, 200],
    this.filtroAtivo = false,
  });

  @override
  Widget build(BuildContext context) {
    final escala = _calcularEscala();
    final pontosDesenho = _montarSerie(escala, (i) => pontos[i].y);
    final pontosAjusteDesenho =
        (ajustes.length == pontos.length && pontos.isNotEmpty)
        ? _montarSerie(escala, (i) => ajustes[i])
        : const <FlSpot>[];

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF252830),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                // So a linha de leitura (indice 0) mostra tooltip; a linha
                // tracejada do ajuste nao.
                if (barSpot.barIndex != 0) return null;
                final index = _indiceOriginalExato(barSpot.x);
                if (index == null) return null;

                final corDoNumero =
                    coresHistoricas.isNotEmpty && index < coresHistoricas.length
                    ? coresHistoricas[index]
                    : corAtual;
                final date = DateTime.fromMillisecondsSinceEpoch(
                  pontos[index].x.toInt(),
                );
                final ajuste = index < ajustes.length
                    ? ajustes[index].round()
                    : null;
                final valorReal = pontos[index].y.round();

                return LineTooltipItem(
                  'Leitura: $valorReal$unidade\n',
                  TextStyle(
                    color: corDoNumero,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    if (ajuste != null)
                      const TextSpan(
                        text: 'Ajuste: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                    if (ajuste != null)
                      TextSpan(
                        text: '$ajuste$unidade\n',
                        style: TextStyle(
                          color: corAtual,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    TextSpan(
                      text: DateFormat('HH:mm').format(date),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            // A linha do ajuste (tracejada) nao recebe destaque de toque.
            if (barData.dashArray != null) {
              return spotIndexes
                  .map(
                    (_) => TouchedSpotIndicatorData(
                      const FlLine(color: Colors.transparent, strokeWidth: 0),
                      const FlDotData(show: false),
                    ),
                  )
                  .toList();
            }
            return spotIndexes.map((index) {
              final indiceOriginal = index < pontosDesenho.length
                  ? _indiceOriginalExato(pontosDesenho[index].x)
                  : null;
              if (indiceOriginal == null) {
                return TouchedSpotIndicatorData(
                  const FlLine(color: Colors.transparent, strokeWidth: 0),
                  const FlDotData(show: false),
                );
              }

              final corNoPonto = indiceOriginal < coresHistoricas.length
                  ? coresHistoricas[indiceOriginal]
                  : corAtual;

              return TouchedSpotIndicatorData(
                FlLine(
                  color: corNoPonto.withValues(alpha: 0.6),
                  strokeWidth: 3,
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 7,
                        color: corNoPonto,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                ),
              );
            }).toList();
          },
        ),
        minX: escala.minX,
        maxX: escala.maxX,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          checkToShowHorizontalLine: (value) =>
              rotulosY.contains(value.round()),
          verticalInterval: escala.intervaloRotuloMs,
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 42,
              getTitlesWidget: (value, axisMeta) {
                final valorInt = value.round();

                if (!rotulosY.contains(valorInt)) {
                  return const SizedBox();
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$valorInt$unidade',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: escala.intervaloRotuloMs,
              reservedSize: 30,
              getTitlesWidget: (value, axisMeta) {
                if (pontos.isEmpty) return const SizedBox();

                if (value < axisMeta.min + 1000 ||
                    value > axisMeta.max - 1000 ||
                    value > escala.dadosMaxX + 1000) {
                  return const SizedBox();
                }

                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    DateFormat('HH:mm').format(date),
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: pontosDesenho,
            // Degraus (nao curva): o valor e constante entre leituras. Evita
            // as "alcas" que a curva spline criava com pontos proximos.
            isCurved: false,
            isStepLineChart: true,
            barWidth: 3,
            color: corAtual,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => _deveMostrarPonto(spot, escala),
              getDotPainter: (spot, percent, barData, index) {
                final indiceOriginal = _indiceOriginalMaisProximo(spot.x);
                final corNoPonto = indiceOriginal < coresHistoricas.length
                    ? coresHistoricas[indiceOriginal]
                    : corAtual;
                return FlDotCirclePainter(
                  radius: 3.8,
                  color: corNoPonto,
                  strokeWidth: 1.4,
                  strokeColor: const Color(0xFF0E1012),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  corAtual.withValues(alpha: 0.15),
                  corAtual.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Linha do ajuste (setpoint) em degraus tracejados, para comparar a
          // leitura com o ajuste. Sem pontos e sem tooltip proprio.
          if (pontosAjusteDesenho.isNotEmpty)
            LineChartBarData(
              spots: pontosAjusteDesenho,
              isCurved: false,
              isStepLineChart: true,
              barWidth: 1.4,
              color: Colors.white.withValues(alpha: 0.45),
              dashArray: const [6, 5],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  _EscalaGrafico _calcularEscala() {
    const intervaloSemFiltro = Duration(minutes: 10);
    const janelaSemFiltro = Duration(hours: 1);

    if (pontos.isEmpty) {
      final agora = DateTime.now().millisecondsSinceEpoch.toDouble();
      final intervaloRotuloMs = intervaloSemFiltro.inMilliseconds.toDouble();
      final maxXBase = _arredondarParaCimaIntervalo(agora, intervaloRotuloMs);
      final minXBase = maxXBase - janelaSemFiltro.inMilliseconds;
      return _EscalaGrafico(
        minX: minXBase - intervaloRotuloMs * 0.55,
        maxX: maxXBase + intervaloRotuloMs * 0.55,
        intervaloRotuloMs: intervaloRotuloMs,
        primeiroPontoX: agora,
        ultimoPontoX: agora,
        dadosMinX: minXBase,
        dadosMaxX: maxXBase,
        totalPontosVisiveis: 0,
      );
    }

    final primeiroX = pontos.first.x;
    final ultimoX = pontos.last.x;
    final agoraX = DateTime.now().millisecondsSinceEpoch.toDouble();
    final intervaloBaseMs = intervaloSemFiltro.inMilliseconds.toDouble();
    final maxXSemFiltro = _arredondarParaCimaIntervalo(
      ultimoX > agoraX ? ultimoX : agoraX,
      intervaloBaseMs,
    );
    final minXBase = filtroAtivo
        ? primeiroX
        : maxXSemFiltro - janelaSemFiltro.inMilliseconds;
    final maxXBase = filtroAtivo ? ultimoX : maxXSemFiltro;
    final intervaloRotuloMs = _intervaloParaDuracao(
      (maxXBase - minXBase).abs(),
    );
    final margemX = intervaloRotuloMs * 0.55;
    final minX = minXBase - margemX;
    final maxX = maxXBase + margemX;
    final duracaoMs = (maxX - minX).abs();
    final pontosVisiveis = pontos
        .where((spot) => spot.x >= minXBase && spot.x <= maxXBase)
        .toList();
    final primeiroVisivelX = pontosVisiveis.isEmpty
        ? primeiroX
        : pontosVisiveis.first.x;
    final ultimoVisivelX = pontosVisiveis.isEmpty
        ? ultimoX
        : pontosVisiveis.last.x;

    return _EscalaGrafico(
      minX: minX,
      maxX: maxX,
      intervaloRotuloMs: _intervaloParaDuracao(duracaoMs),
      primeiroPontoX: primeiroVisivelX,
      ultimoPontoX: ultimoVisivelX,
      dadosMinX: minXBase,
      dadosMaxX: maxXBase,
      totalPontosVisiveis: pontosVisiveis.length,
    );
  }

  // Monta uma serie de pontos (leitura ou ajuste) recortada na janela visivel,
  // com pontos de entrada/saida nas bordas para a linha nao "flutuar".
  List<FlSpot> _montarSerie(
    _EscalaGrafico escala,
    double Function(int i) valorDe,
  ) {
    if (pontos.isEmpty) return const [];

    final indices = <int>[];
    for (var i = 0; i < pontos.length; i++) {
      if (pontos[i].x >= escala.dadosMinX && pontos[i].x <= escala.dadosMaxX) {
        indices.add(i);
      }
    }
    if (indices.isEmpty) return const [];
    if (indices.length == 1) {
      final i = indices.first;
      return [FlSpot(pontos[i].x, _limitarY(valorDe(i)))];
    }

    final primeiro = indices.first;
    final ultimo = indices.last;
    final pontoEntrada = primeiro > 0
        ? FlSpot(escala.minX, _limitarY(valorDe(primeiro)))
        : null;
    final pontoSaida = FlSpot(escala.maxX, _limitarY(valorDe(ultimo)));
    return [
      if (pontoEntrada != null) pontoEntrada,
      for (final i in indices) FlSpot(pontos[i].x, _limitarY(valorDe(i))),
      pontoSaida,
    ];
  }

  double _intervaloParaDuracao(double duracaoMs) {
    if (!filtroAtivo) {
      return const Duration(minutes: 10).inMilliseconds.toDouble();
    }

    final duracao = Duration(milliseconds: duracaoMs.round());
    if (duracao <= const Duration(minutes: 10)) {
      return const Duration(minutes: 1).inMilliseconds.toDouble();
    }
    if (duracao <= const Duration(hours: 1)) {
      return const Duration(minutes: 10).inMilliseconds.toDouble();
    }
    if (duracao <= const Duration(hours: 6)) {
      return const Duration(minutes: 30).inMilliseconds.toDouble();
    }
    if (duracao <= const Duration(hours: 24)) {
      return const Duration(hours: 2).inMilliseconds.toDouble();
    }
    return const Duration(hours: 6).inMilliseconds.toDouble();
  }

  bool _deveMostrarPonto(FlSpot spot, _EscalaGrafico escala) {
    if (spot.x < escala.dadosMinX || spot.x > escala.dadosMaxX) {
      return false;
    }

    if (_estaForaDaTolerancia(spot)) {
      return true;
    }

    final distanciaInicio = (spot.x - escala.primeiroPontoX).abs();
    final distanciaFim = (spot.x - escala.ultimoPontoX).abs();
    final tolerancia = escala.intervaloRotuloMs / 4;

    if (distanciaInicio <= tolerancia || distanciaFim <= tolerancia) {
      return true;
    }

    final deslocamento = (spot.x - escala.dadosMinX) % escala.intervaloRotuloMs;
    final distanciaIntervalo = deslocamento < escala.intervaloRotuloMs / 2
        ? deslocamento
        : escala.intervaloRotuloMs - deslocamento;
    return distanciaIntervalo <= tolerancia;
  }

  bool _estaForaDaTolerancia(FlSpot spot) {
    final index = _indiceOriginalExato(spot.x);
    if (index == null || index >= ajustes.length) return false;

    return (pontos[index].y - ajustes[index]).abs() > 5;
  }

  double _limitarY(double valor) {
    final menorRotulo = rotulosY.isEmpty ? minY : rotulosY.first.toDouble();
    final maiorRotulo = rotulosY.isEmpty ? maxY : rotulosY.last.toDouble();

    return valor.clamp(menorRotulo, maiorRotulo).toDouble();
  }

  int _indiceOriginalMaisProximo(double x) {
    if (pontos.isEmpty) return 0;

    var melhorIndice = 0;
    var melhorDistancia = (pontos.first.x - x).abs();
    for (var i = 1; i < pontos.length; i++) {
      final distancia = (pontos[i].x - x).abs();
      if (distancia < melhorDistancia) {
        melhorIndice = i;
        melhorDistancia = distancia;
      }
    }
    return melhorIndice;
  }

  int? _indiceOriginalExato(double x) {
    for (var i = 0; i < pontos.length; i++) {
      if ((pontos[i].x - x).abs() <= 1) return i;
    }
    return null;
  }

  double _arredondarParaBaixoMinuto(double valorMs) {
    final data = DateTime.fromMillisecondsSinceEpoch(valorMs.round());
    return DateTime(
      data.year,
      data.month,
      data.day,
      data.hour,
      data.minute,
    ).millisecondsSinceEpoch.toDouble();
  }

  double _arredondarParaBaixoIntervalo(double valorMs, double intervaloMs) {
    final minutoMs = _arredondarParaBaixoMinuto(valorMs);
    return minutoMs - (minutoMs % intervaloMs);
  }

  double _arredondarParaCimaIntervalo(double valorMs, double intervaloMs) {
    final base = _arredondarParaBaixoIntervalo(valorMs, intervaloMs);
    if ((valorMs - base).abs() <= 1) return base;
    return base + intervaloMs;
  }
}

class _EscalaGrafico {
  final double minX;
  final double maxX;
  final double intervaloRotuloMs;
  final double primeiroPontoX;
  final double ultimoPontoX;
  final double dadosMinX;
  final double dadosMaxX;
  final int totalPontosVisiveis;

  const _EscalaGrafico({
    required this.minX,
    required this.maxX,
    required this.intervaloRotuloMs,
    required this.primeiroPontoX,
    required this.ultimoPontoX,
    required this.dadosMinX,
    required this.dadosMaxX,
    required this.totalPontosVisiveis,
  });
}
