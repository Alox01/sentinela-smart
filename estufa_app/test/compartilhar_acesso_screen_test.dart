import 'package:estufa_app/features/home/models/convite_estufa.dart';
import 'package:estufa_app/features/home/models/link_convite.dart';
import 'package:estufa_app/features/home/screens/compartilhar_acesso_screen.dart';
import 'package:estufa_app/features/monitoramento/widgets/menu_estufa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// A tela de compartilhar acesso.
///
/// Tres modos de falha justificam este arquivo:
///
/// 1. **O QR desenhar o convite errado.** Um quadrado preto e branco parece
///    certo de qualquer jeito; ninguem confere um QR olhando. O teste afirma o
///    conteudo exato, e que ele bate com o que [LinkConvite] monta.
/// 2. **O aviso sumir numa reforma de layout.** O texto sobre a chave ficar
///    gravada na conversa e o unico lugar onde o produtor descobre a diferenca
///    entre os dois botoes. Ele nao pode virar vitima de uma limpeza.
/// 3. **A gaveta montar o convite com o campo trocado.** `chave` e `idHardware`
///    sao os dois `String?` de [ConviteEstufa], e o menu os preenche a partir de
///    dois `String?` de `DadosMenuEstufa`. Trocar um pelo outro compila, passa
///    no `analyze`, desenha um QR de aparencia normal — e entrega a chave errada
///    no celular de outra pessoa. Os testes acima nao alcancam isso: eles
///    recebem o convite pronto. A costura entre a gaveta e a tela precisa de
///    prova propria.
void main() {
  const convite = ConviteEstufa(
    nome: 'Estufa do Fundo',
    endereco: 'sentinela-215788.local',
    chave: 'chave-longa-do-aparelho',
    idHardware: 'ESP32_215788',
  );

  Future<void> abrir(WidgetTester tester) async {
    // A tela tem os dois cartoes mais o aviso; numa janela de teste padrao o
    // rolamento esconderia o de baixo e o teste acusaria sumico onde nao ha.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: CompartilharAcessoScreen(convite: convite)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('o QR carrega o convite desta estufa, e não outro', (
    tester,
  ) async {
    await abrir(tester);

    final qr = tester.widget<QrDoConvite>(find.byType(QrDoConvite));

    expect(qr.endereco, LinkConvite.montar(convite));
    // Prova que o dado nao e uma casca: o convite volta inteiro de dentro do
    // que foi desenhado.
    final devolta = LinkConvite.ler(Uri.parse(qr.endereco));
    expect(devolta?.endereco, 'sentinela-215788.local');
    expect(devolta?.chave, 'chave-longa-do-aparelho');
  });

  testWidgets('só o QR entrega o convite', (tester) async {
    await abrir(tester);

    // O QR nao substitui o texto: quem esta longe continua sendo atendido.
    expect(find.byType(QrImageView), findsOneWidget);
    // O convite escrito saiu: ficaria gravado na conversa com a chave dentro.
    expect(find.text('Enviar por mensagem'), findsNothing);
    expect(find.text('QUEM ESTÁ DO SEU LADO'), findsOneWidget);
    expect(find.text('QUEM ESTÁ LONGE'), findsNothing);
  });

  testWidgets('a tela diz que o convite escrito fica gravado para sempre', (
    tester,
  ) async {
    await abrir(tester);

    // A tela NAO pode prometer que nao sobra copia: o Android guarda um
    // instantaneo dela para a lista de Recentes, com o QR desenhado, e nada
    // impede print. O contraste verdadeiro e sobre a conversa, nao sobre a sala.
    expect(find.textContaining('não sai desta sala'), findsNothing);
    expect(
      find.textContaining('não fica gravado em conversa'),
      findsOneWidget,
      reason: 'é a única razão para preferir o QR quando os dois estão juntos',
    );
    // A chave comanda de fora da rede, e o texto tem de dizer isso: lido como
    // "so na minha rede", o produtor manda o convite com outro criterio.
    expect(find.textContaining('de qualquer lugar, pela'), findsOneWidget);
    expect(
      find.text('O convite carrega a chave da estufa'),
      findsOneWidget,
    );
  });

  testWidgets('a estufa compartilhada aparece pelo nome', (tester) async {
    await abrir(tester);

    // Sem isto o produtor com duas estufas nao tem como saber qual QR esta
    // mostrando — e compartilhar a errada entrega a chave errada.
    expect(find.text('Estufa do Fundo'), findsOneWidget);
  });

  group('o convite que a gaveta entrega a esta tela', () {
    /// Abre a gaveta da estufa e toca em "Compartilhar acesso", como o produtor
    /// faz. Devolve o convite com que a tela nasceu.
    Future<ConviteEstufa> compartilharPelaGaveta(WidgetTester tester) async {
      // A gaveta tem ~1.200 px de conteudo; numa janela padrao o `ListView` nao
      // construiria o item la embaixo e o toque nao encontraria alvo.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Mesmo lugar em que a tela de monitoramento a pendura.
            endDrawer: MenuEstufa(
              dados: DadosMenuEstufa(
                idEstufa: 7,
                nomeEstufa: 'Estufa do Fundo',
                ipEstufa: '192.168.0.50',
                tokenAcesso: 'chave-de-teste',
                idHardware: 'AABBCCDDEEFF',
                temperaturaAjuste: 130,
                umidadeAjuste: 45,
                buzzerAparelhoAtivo: null,
                vigiada: null,
                temperaturaNovaEstufada: 95,
                umidadeNovaEstufada: 60,
              ),
              acoes: AcoesMenuEstufa(
                aoAbrirDetalhesConexao: () {},
                aoConfigurarAparelho: () {},
                aoReiniciarAjustes: () {},
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compartilhar acesso'));
      await tester.pumpAndSettle();

      return tester
          .widget<CompartilharAcessoScreen>(
            find.byType(CompartilharAcessoScreen),
          )
          .convite;
    }

    testWidgets('leva os quatro campos da estufa aberta, sem troca', (
      tester,
    ) async {
      final entregue = await compartilharPelaGaveta(tester);

      // `chave` e `idHardware` sao afirmados um a um de proposito: sao os dois
      // campos que se aceitam mutuamente e cujo erro so aparece depois, no
      // outro celular.
      expect(entregue.nome, 'Estufa do Fundo');
      expect(entregue.endereco, '192.168.0.50');
      expect(entregue.chave, 'chave-de-teste');
      expect(entregue.idHardware, 'AABBCCDDEEFF');
    });

    testWidgets('chega inteiro do outro lado do QR', (tester) async {
      final entregue = await compartilharPelaGaveta(tester);

      // Fecha o circuito: da gaveta ao endereco do QR e de volta a um convite.
      // E este o percurso que o celular de quem recebe faz.
      final devolta = LinkConvite.ler(
        Uri.parse(LinkConvite.montar(entregue)),
      );

      expect(devolta?.endereco, '192.168.0.50');
      expect(devolta?.chave, 'chave-de-teste');
      expect(devolta?.idHardware, 'AABBCCDDEEFF');
    });
  });
}
