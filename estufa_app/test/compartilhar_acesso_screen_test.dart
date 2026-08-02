import 'package:estufa_app/features/home/models/convite_estufa.dart';
import 'package:estufa_app/features/home/models/link_convite.dart';
import 'package:estufa_app/features/home/screens/compartilhar_acesso_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// A tela de compartilhar acesso.
///
/// Dois modos de falha justificam este arquivo:
///
/// 1. **O QR desenhar o convite errado.** Um quadrado preto e branco parece
///    certo de qualquer jeito; ninguem confere um QR olhando. O teste afirma o
///    conteudo exato, e que ele bate com o que [LinkConvite] monta.
/// 2. **O aviso sumir numa reforma de layout.** O texto sobre a chave ficar
///    gravada na conversa e o unico lugar onde o produtor descobre a diferenca
///    entre os dois botoes. Ele nao pode virar vitima de uma limpeza.
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

  testWidgets('as duas formas de entregar convivem na tela', (tester) async {
    await abrir(tester);

    // O QR nao substitui o texto: quem esta longe continua sendo atendido.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Enviar por mensagem'), findsOneWidget);
    expect(find.text('QUEM ESTÁ DO SEU LADO'), findsOneWidget);
    expect(find.text('QUEM ESTÁ LONGE'), findsOneWidget);
  });

  testWidgets('a tela diz que o convite escrito fica gravado para sempre', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.textContaining('O QR não sai desta sala'), findsOneWidget);
    expect(
      find.textContaining('fica gravado na conversa'),
      findsOneWidget,
      reason: 'é a única razão para preferir o QR quando os dois estão juntos',
    );
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
}
