import 'package:estufa_app/features/relatorio_estufada/widgets/eventos_estufada_card.dart';
import 'package:estufa_app/models/ciclo_secagem_entity.dart';
import 'package:estufa_app/models/evento_ciclo_entity.dart';
import 'package:estufa_app/widgets/painel_controle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Os dois defeitos visuais achados em campo em 15/09/2026 (D10 e D11 da
/// auditoria).
void main() {
  Widget emTela(Widget filho) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: filho)),
  );

  group('D10 - ajuste sem base conhecida', () {
    // Abrir a estufa sem conexão mostrava 0 °F, 0% e ajuste 0 — números que o
    // app nunca leu de aparelho nenhum, com a mesma cara dos de verdade. E os
    // botões + e − trabalhavam sobre esse zero: um toque pedia ajuste de 1 °F,
    // que entrava na fila e seria aplicado na volta da internet.

    testWidgets('mostra traco em vez de zero', (tester) async {
      await tester.pumpWidget(
        emTela(
          PainelControle(
            tempAjuste: 0,
            umidAjuste: 0,
            baseConhecida: false,
            onMudarTemperatura: (_) {},
            onMudarUmidade: (_) {},
          ),
        ),
      );

      expect(find.text('--'), findsNWidgets(2));
      expect(
        find.text('0'),
        findsNothing,
        reason: 'zero aqui é um número que o produtor acredita',
      );
    });

    testWidgets('o toque em + e - nao manda nada', (tester) async {
      final pedidos = <double>[];
      await tester.pumpWidget(
        emTela(
          PainelControle(
            tempAjuste: 0,
            umidAjuste: 0,
            baseConhecida: false,
            onMudarTemperatura: pedidos.add,
            onMudarUmidade: pedidos.add,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pump();

      expect(
        pedidos,
        isEmpty,
        reason: 'ajustou a partir de um valor que o app inventou',
      );
    });

    testWidgets('com base conhecida, continua ajustando normalmente', (
      tester,
    ) async {
      // Ajustar sem internet é proposital e o produtor usa: o que não pode é
      // ajustar sem saber de onde se está partindo.
      final pedidos = <double>[];
      await tester.pumpWidget(
        emTela(
          PainelControle(
            tempAjuste: 90,
            umidAjuste: 80,
            onMudarTemperatura: pedidos.add,
            onMudarUmidade: pedidos.add,
          ),
        ),
      );

      expect(find.text('90'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      expect(pedidos, [91.0]);
    });
  });

  group('D11 - virada de dia nos eventos', () {
    EventoCicloEntity evento(DateTime quando, String descricao) {
      final e = EventoCicloEntity()
        ..cicloId = 1
        ..timestamp = quando
        ..tipo = 'ajuste'
        ..severidade = 'info'
        ..descricao = descricao;
      return e;
    }

    final ciclo = CicloSecagemEntity()
      ..ipEstufa = '192.168.0.10'
      ..nomeEstufa = 'Estufa 1'
      ..inicio = DateTime(2026, 9, 14, 14, 9);

    testWidgets('estufada que passa da meia-noite mostra a data', (
      tester,
    ) async {
      // 19:02, 19:11, 08:00, 13:06 parecia fora de ordem, e a ordem estava
      // certa: o que faltava era o dia.
      await tester.pumpWidget(
        emTela(
          EventosEstufadaCard(
            cicloSelecionado: ciclo,
            tituloSecaoStyle: const TextStyle(),
            eventos: [
              evento(DateTime(2026, 9, 14, 19, 2), 'Ajuste para 95 F'),
              evento(DateTime(2026, 9, 14, 19, 11), 'Ajuste para 100 F'),
              evento(DateTime(2026, 9, 15, 8, 0), 'Ajuste para 105 F'),
              evento(DateTime(2026, 9, 15, 13, 6), 'Ajuste para 110 F'),
            ],
          ),
        ),
      );

      expect(find.text('14/09'), findsOneWidget);
      expect(find.text('15/09'), findsOneWidget);
      expect(find.text('19:02'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('estufada de um dia so nao ganha faixa de data', (
      tester,
    ) async {
      // A data já está no cabeçalho da estufada selecionada; repeti-la aqui
      // seria ruído.
      await tester.pumpWidget(
        emTela(
          EventosEstufadaCard(
            cicloSelecionado: ciclo,
            tituloSecaoStyle: const TextStyle(),
            eventos: [
              evento(DateTime(2026, 9, 14, 19, 2), 'Ajuste para 95 F'),
              evento(DateTime(2026, 9, 14, 19, 11), 'Ajuste para 100 F'),
            ],
          ),
        ),
      );

      expect(find.text('14/09'), findsNothing);
      expect(find.text('19:02'), findsOneWidget);
    });
  });
}
