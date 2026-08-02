import 'dart:async';

import 'package:estufa_app/features/home/models/convite_estufa.dart';
import 'package:estufa_app/features/home/models/link_convite.dart';
import 'package:estufa_app/features/home/widgets/ouvinte_convite_link.dart';
import 'package:estufa_app/screens/estufa_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O outro lado do QR: o celular que recebe.
///
/// ## O que este arquivo NAO prova
///
/// Nao prova que a camera do celular reconhece o codigo, nem que o Android
/// oferece o Sentinela para abrir o endereco. Isso mora no `AndroidManifest` e
/// no sistema operacional, e so um aparelho responde por ele — ver o roteiro de
/// teste manual no relato da tarefa.
///
/// ## O que ele prova
///
/// O que sobra depois que o endereco chega ao app, que e onde estao os erros
/// que ninguem ve: engolir endereco que nao e nosso, abrir dois cadastros com
/// uma leitura dupla, e o formulario nascer preenchido com o convite CERTO.
void main() {
  const convite = ConviteEstufa(
    nome: 'Estufa do Fundo',
    endereco: 'sentinela-215788.local',
    chave: 'chave-longa-do-aparelho',
    idHardware: 'ESP32_215788',
  );

  group('o ouvinte de endereços', () {
    late StreamController<Uri> sistema;
    late List<ConviteEstufa> recebidos;

    setUp(() {
      sistema = StreamController<Uri>.broadcast();
      recebidos = [];
    });

    tearDown(() => sistema.close());

    Future<void> montar(
      WidgetTester tester, {
      Future<void> Function(ConviteEstufa)? aoReceber,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OuvinteConviteLink(
            enderecos: sistema.stream,
            aoReceber:
                aoReceber ??
                (c) async {
                  recebidos.add(c);
                },
            child: const SizedBox.shrink(),
          ),
        ),
      );
    }

    testWidgets('entrega o convite que veio no endereço', (tester) async {
      await montar(tester);

      sistema.add(Uri.parse(LinkConvite.montar(convite)));
      await tester.pump();

      expect(recebidos, hasLength(1));
      expect(recebidos.single.endereco, 'sentinela-215788.local');
      expect(recebidos.single.chave, 'chave-longa-do-aparelho');
    });

    testWidgets('cala diante de endereço que não é convite nosso', (
      tester,
    ) async {
      await montar(tester);

      // O app pode ser acordado por qualquer coisa. Nenhum destes deve abrir
      // cadastro, e nenhum deve virar erro na tela do produtor.
      sistema.add(Uri.parse('https://exemplo.com/qualquer'));
      sistema.add(Uri.parse('sentinela://ajuste?c=lixo'));
      sistema.add(Uri.parse('sentinela://convite'));
      sistema.add(Uri.parse('sentinela://convite?c=bom%20dia'));
      await tester.pump();

      expect(recebidos, isEmpty);
    });

    testWidgets('leitura dupla do mesmo QR não abre dois cadastros', (
      tester,
    ) async {
      // Celular ja apontado para o codigo dispara duas leituras com facilidade.
      // Dois formularios empilhados fariam o produtor cadastrar a mesma estufa
      // duas vezes — e duas estufas no mesmo endereco passam a mostrar os dados
      // do mesmo aparelho, que e o estado que o cadastro tenta impedir.
      final aberto = Completer<void>();
      var chamadas = 0;
      await montar(
        tester,
        aoReceber: (_) {
          chamadas++;
          return aberto.future;
        },
      );

      final endereco = Uri.parse(LinkConvite.montar(convite));
      sistema.add(endereco);
      await tester.pump();
      sistema.add(endereco);
      await tester.pump();

      expect(chamadas, 1, reason: 'o segundo chegou com o primeiro em aberto');

      // Fechado o cadastro, o proximo convite volta a ser atendido — o travamento
      // e temporario, nao definitivo.
      aberto.complete();
      await tester.pump();
      sistema.add(endereco);
      await tester.pump();

      expect(chamadas, 2);
    });
  });

  group('o formulário que o convite abre', () {
    testWidgets('nasce preenchido, sem passar por "Colar convite"', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: EstufaFormScreen(convite: convite)),
      );
      await tester.pump();

      final campos = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((c) => c.controller?.text)
          .toList();

      // Nome, endereco e id do aparelho. A chave nao tem campo quando ja veio
      // preenchida — ela vira uma linha, de proposito: ver o convite nao e
      // tarefa do produtor.
      expect(campos, ['Estufa do Fundo', 'sentinela-215788.local', 'ESP32_215788']);
      expect(find.text('Chave de acesso: configurada'), findsOneWidget);
    });

    testWidgets('sem convite continua o formulário em branco de sempre', (
      tester,
    ) async {
      // A mesma tela serve aos tres caminhos (a mao, colar, QR). Este e o
      // guarda de que o caminho novo nao mudou os antigos.
      await tester.pumpWidget(const MaterialApp(home: EstufaFormScreen()));
      await tester.pump();

      final campos = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((c) => c.controller?.text)
          .toList();

      expect(campos, ['', '', '', '']);
      expect(find.text('Colar convite'), findsOneWidget);
    });
  });
}
