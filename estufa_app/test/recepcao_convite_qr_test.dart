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
            // Um `Scaffold` porque o ouvinte agora tem o que dizer em um dos
            // casos, e o `ScaffoldMessenger` so desenha dentro de um.
            child: const Scaffold(body: SizedBox.shrink()),
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
      // cadastro, e nenhum deve virar erro na tela do produtor: ele nao pediu
      // nada, e um aviso seria sobre um endereco que ele nem sabe que existe.
      sistema.add(Uri.parse('https://exemplo.com/qualquer'));
      sistema.add(Uri.parse('sentinela://ajuste?c=lixo'));
      await tester.pump();

      expect(recebidos, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('convite nosso que chegou estragado NÃO falha em silêncio', (
      tester,
    ) async {
      // O caso que este teste guarda: o produtor apontou a camera, o Android
      // ofereceu o Sentinela, ele tocou — e o app abriu e nao fez nada. Sem
      // mensagem, sem pista, no celular de outra pessoa. E vai acontecer:
      // `decodificar` recusa de proposito o formato que nao conhece, entao um
      // app antigo lendo convite de formato novo cai exatamente aqui.
      await montar(tester);

      sistema.add(Uri.parse('sentinela://convite?c=bom%20dia'));
      await tester.pump();
      await tester.pump(); // deixa o SnackBar entrar

      expect(recebidos, isEmpty, reason: 'nao da para cadastrar meia estufa');
      expect(find.text(ConviteEstufa.avisoIlegivel), findsOneWidget);
    });

    testWidgets('endereço nosso sem convite nenhum também avisa', (
      tester,
    ) async {
      // Mesma situacao: o endereco e nosso, o produtor pediu, e nao ha o que
      // cadastrar. Silencio aqui era indistinguivel de app quebrado.
      await montar(tester);

      sistema.add(Uri.parse('sentinela://convite'));
      await tester.pump();
      await tester.pump();

      expect(recebidos, isEmpty);
      expect(find.text(ConviteEstufa.avisoIlegivel), findsOneWidget);
    });

    testWidgets('o aviso é o mesmo do caminho de "Colar convite"', (
      tester,
    ) async {
      // A assimetria original: colar avisava, o QR calava. As duas frases sao
      // agora a mesma constante — e este teste falha se alguem escrever de novo
      // uma frase propria para um dos lados.
      await montar(tester);
      sistema.add(Uri.parse('sentinela://convite?c=nada%20disso'));
      await tester.pump();
      await tester.pump();

      final aviso = tester.widget<Text>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(Text),
        ),
      );
      expect(aviso.data, ConviteEstufa.avisoIlegivel);
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

      // Janela alta o bastante para "Opcoes avancadas" caber: na altura padrao
      // ela fica fora da tela e o toque nao encontra alvo.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      // Na vista normal so aparecem nome e endereco: chave e id nao sao assunto
      // do produtor e foram para "Opcoes avancadas".
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((c) => c.controller?.text)
            .toList(),
        ['Estufa do Fundo', 'sentinela-215788.local'],
      );

      // Chave e id nao tem campo nenhum nesta tela — nem escondido. O convite
      // preenche os dois por baixo, e e o que o cadastro grava.
      expect(find.text('Chave de acesso'), findsNothing);
      expect(find.text('ID do aparelho'), findsNothing);
    });

    testWidgets('sem convite continua o formulário em branco de sempre', (
      tester,
    ) async {
      // A mesma tela serve aos tres caminhos (a mao, colar, QR). Este e o
      // guarda de que o caminho novo nao mudou os antigos.
      await tester.pumpWidget(const MaterialApp(home: EstufaFormScreen()));
      await tester.pump();

      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((c) => c.controller?.text)
            .toList(),
        ['', ''],
      );

      expect(find.text('Usar a estufa de demonstração'), findsOneWidget);
    });
  });
}
