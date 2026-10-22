import 'package:estufa_app/features/relatorio_estufada/widgets/seletor_estufada_periodo_card.dart';
import 'package:estufa_app/models/ciclo_secagem_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O relatório mostra UM DIA de cada vez, e é por aqui que se troca de dia.
///
/// Antes o filtro tinha início e fim independentes, cada um com data, hora e
/// minuto, mais intervalo mínimo de uma hora, limpar filtro e os avisos de
/// intervalo inválido. O que o produtor faz com isso é sempre o mesmo: olhar um
/// dia da estufada. A troca removeu os casos que ninguém usava (intervalo
/// invertido, só o início preenchido, exportação parcial) e deixou três
/// controles: dia anterior, o dia, dia seguinte.
///
/// O modo de falha agora é outro: uma seta que para de chamar o que devia, ou
/// que continua acesa no primeiro dia e não faz nada. Nada fica vermelho quando
/// isso acontece — o cartão desenha igual.
void main() {
  final ciclo = CicloSecagemEntity()
    ..id = 7
    ..ipEstufa = '192.168.0.10'
    ..nomeEstufa = 'Estufa 1'
    ..inicio = DateTime(2026, 9, 14, 14, 9)
    ..status = 'em_andamento'
    ..observacao = '';

  Future<void> montar(
    WidgetTester tester, {
    DateTime? dia,
    VoidCallback? aoSelecionar,
    VoidCallback? aoAnterior,
    VoidCallback? aoProximo,
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeletorEstufadaPeriodoCard(
            ciclos: [ciclo],
            cicloSelecionadoId: 7,
            diaSelecionado: dia,
            tituloSecaoStyle: const TextStyle(),
            onCicloChanged: (_) {},
            onSelecionarDia: aoSelecionar,
            onDiaAnterior: aoAnterior,
            onProximoDia: aoProximo,
            rotuloCiclo: (_) => '1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // `byTooltip` acha a dica, nao o botao; quem guarda o `onPressed` e o
  // `IconButton` acima do icone.
  bool habilitado(WidgetTester tester, IconData icone) =>
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(icone),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed !=
      null;

  testWidgets('o dia aberto aparece por extenso', (tester) async {
    await montar(tester, dia: DateTime(2026, 9, 15));

    expect(find.text('15/09/2026'), findsOneWidget);
  });

  testWidgets('sem dia escolhido, convida a escolher', (tester) async {
    // É o estado da estufada sem leitura nenhuma: não há dia para abrir.
    await montar(tester);

    expect(find.text('Selecione um dia'), findsOneWidget);
  });

  testWidgets('as setas chamam quem troca o dia', (tester) async {
    var anterior = 0;
    var proximo = 0;
    await montar(
      tester,
      dia: DateTime(2026, 9, 15),
      aoAnterior: () => anterior++,
      aoProximo: () => proximo++,
    );

    await tester.tap(find.byTooltip('Dia anterior'));
    await tester.tap(find.byTooltip('Próximo dia'));

    expect(anterior, 1);
    expect(proximo, 1);
  });

  testWidgets('no primeiro dia da estufada, voltar fica apagado', (
    tester,
  ) async {
    // A tela passa `null` nas pontas. Seta acesa que não anda é pior do que
    // apagada: quem toca conclui que o relatório travou.
    await montar(tester, dia: DateTime(2026, 9, 14), aoProximo: () {});

    expect(habilitado(tester, Icons.chevron_left), isFalse);
    expect(habilitado(tester, Icons.chevron_right), isTrue);
  });

  testWidgets('diz que o arquivo não acompanha o dia', (tester) async {
    // A pergunta que isto responde antes de ser feita: "baixei no dia 15, veio
    // só o dia 15?". O PDF e o CSV são sempre da estufada inteira.
    await montar(tester, dia: DateTime(2026, 9, 15), aoSelecionar: () {});

    expect(
      find.text('O PDF e o CSV sempre incluem a estufada completa.'),
      findsOneWidget,
    );
  });
}
