import 'package:estufa_app/features/relatorio_estufada/widgets/grafico_estufada_card.dart';
import 'package:estufa_app/models/historico_leitura_entity.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O gráfico da estufada desenha mesmo as linhas e os pontos?
///
/// A pergunta veio do campo — houve uma época em que o cartão abria vazio — e
/// não tinha resposta possível sem abrir o app e olhar. Um gráfico vazio é
/// silencioso: o cartão aparece, a moldura desenha, os botões de Temperatura e
/// Umidade funcionam, e só falta o desenho. Nada fica vermelho e nada é
/// registrado.
///
/// Este teste alcança o [LineChart] montado e afirma o que ninguém vê no
/// widget: quantos pontos cada série recebeu, e que a série do ajuste acompanha
/// a da leitura. É a diferença entre "a tela abriu" e "o gráfico existe".
void main() {
  HistoricoLeituraEntity leitura({
    required int minuto,
    required double temperatura,
    required double umidade,
    double temperaturaMeta = 130,
    double umidadeMeta = 60,
  }) {
    return HistoricoLeituraEntity()
      ..ipEstufa = '192.168.0.50'
      ..nomeEstufa = 'Estufa do Fundo'
      ..timestamp = DateTime(2026, 8, 4, 9).add(Duration(minutes: minuto))
      ..temperatura = temperatura
      ..umidade = umidade
      ..temperaturaMeta = temperaturaMeta
      ..umidadeMeta = umidadeMeta
      ..aviso = 'Estável'
      ..alertaIncendio = false;
  }

  /// Uma estufada curta, com o ajuste mudando no meio: é o caso em que a linha
  /// tracejada tem de acompanhar em degrau, e não virar uma reta.
  final estufada = [
    for (var i = 0; i < 12; i++)
      leitura(
        minuto: i * 10,
        temperatura: 120 + i.toDouble(),
        umidade: 70 - i.toDouble(),
        temperaturaMeta: i < 6 ? 130 : 140,
      ),
  ];

  Future<LineChartData> desenhar(
    WidgetTester tester, {
    required bool temperatura,
    required List<HistoricoLeituraEntity> leituras,
  }) async {
    // Larga o bastante para não cair no caminho rolável do celular estreito, que
    // embrulha o gráfico em outro widget — o desenho é o mesmo, e aqui o alvo é
    // o conteúdo, não o embrulho.
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GraficoEstufadaCard(
              leituras: leituras,
              graficoTemperatura: temperatura,
              tituloSecaoStyle: const TextStyle(),
              onGraficoChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return tester.widget<LineChart>(find.byType(LineChart)).data;
  }

  testWidgets('a linha da temperatura recebe um ponto por leitura', (
    tester,
  ) async {
    final dados = await desenhar(
      tester,
      temperatura: true,
      leituras: estufada,
    );

    expect(dados.lineBarsData, isNotEmpty, reason: 'nenhuma série no gráfico');
    final leituraDesenhada = dados.lineBarsData.first;
    expect(leituraDesenhada.spots.length, estufada.length);
    // Não basta existirem: os valores têm de ser os lidos. Uma série de zeros
    // desenharia uma linha reta colada no chão, que é "aparece mas está errado".
    expect(leituraDesenhada.spots.first.y, 120);
    expect(leituraDesenhada.spots.last.y, 131);
  });

  testWidgets('a linha do ajuste acompanha, com o degrau da mudança', (
    tester,
  ) async {
    final dados = await desenhar(
      tester,
      temperatura: true,
      leituras: estufada,
    );

    expect(
      dados.lineBarsData.length,
      greaterThan(1),
      reason: 'sem a série do ajuste não há com o que comparar a leitura',
    );
    final ajuste = dados.lineBarsData[1];
    expect(ajuste.spots.length, estufada.length);
    expect(ajuste.spots.first.y, 130);
    expect(ajuste.spots.last.y, 140);
  });

  testWidgets('trocar para umidade troca os valores desenhados', (
    tester,
  ) async {
    final dados = await desenhar(
      tester,
      temperatura: false,
      leituras: estufada,
    );

    final leituraDesenhada = dados.lineBarsData.first;
    expect(leituraDesenhada.spots.length, estufada.length);
    // Se o botão trocasse só a cor e o rótulo, isto continuaria em 120.
    expect(leituraDesenhada.spots.first.y, 70);
    expect(leituraDesenhada.spots.last.y, 59);
  });

  testWidgets('uma leitura só ainda desenha um ponto', (tester) async {
    // O começo de toda estufada passa por aqui, e é onde um gráfico costuma
    // desistir: com um ponto não há intervalo, e escala mal calculada some com
    // ele.
    final dados = await desenhar(
      tester,
      temperatura: true,
      leituras: [leitura(minuto: 0, temperatura: 118, umidade: 72)],
    );

    expect(dados.lineBarsData.first.spots.length, 1);
    expect(dados.lineBarsData.first.spots.single.y, 118);
  });
}
