import 'package:estufa_app/features/home/models/convite_estufa.dart';
import 'package:estufa_app/features/home/models/modelo_estufa.dart';
import 'package:estufa_app/features/home/services/atualizacao_estufa.dart';
import 'package:estufa_app/features/home/services/estufas_repository.dart';
import 'package:estufa_app/screens/estufa_form_screen.dart';
import 'package:estufa_app/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Convite de um aparelho que JA esta cadastrado neste celular.
///
/// ## O caso
///
/// A chave girou no aparelho, quem tem a nova manda um convite, e a estufa ja
/// existe aqui. Antes a guarda recusava e nao havia caminho nenhum: o convite
/// servia para ENTRAR, nunca para ATUALIZAR.
///
/// ## O que este arquivo guarda
///
/// A parte perigosa nao e atualizar — e atualizar **sozinho**. Gravar por cima
/// uma chave errada tira o acesso do produtor ate ele ir fisicamente ate o
/// aparelho, e nada na tela ligaria uma coisa a outra. Entao o que os testes
/// afirmam, em ordem de importancia:
///
/// 1. sem confirmacao, **nada e gravado**;
/// 2. a confirmacao diz QUAL estufa muda e O QUE muda;
/// 3. vale para os dois caminhos do convite — o QR e o "Colar convite";
/// 4. digitado a mao (sem convite) a recusa de sempre continua valendo.
void main() {
  const convite = ConviteEstufa(
    nome: 'Estufa do Fundo',
    endereco: 'sentinela-215788.local',
    chave: 'chave-NOVA-do-aparelho',
    idHardware: 'ESP32_215788',
  );

  /// A estufa que ja esta neste celular: mesmo aparelho, chave e endereco
  /// velhos. E o estado depois de o produtor girar a chave la no aparelho.
  const jaCadastrada = ModeloEstufa(
    id: 7,
    nome: 'Estufa do Fundo',
    ip: '192.168.0.50',
    tokenAcesso: 'chave-velha',
    idHardware: 'ESP32_215788',
  );

  group('a conta do que muda', () {
    test('chave e endereço novos mudam os dois', () {
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 7,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-velha',
        idHardwareAtual: 'ESP32_215788',
        enderecoNovo: 'sentinela-215788.local',
        chaveNova: 'chave-NOVA-do-aparelho',
        idHardwareNovo: 'ESP32_215788',
      );

      expect(mudanca, isNotNull);
      expect(mudanca!.mudaChave, isTrue);
      expect(mudanca.mudaEndereco, isTrue);
      expect(mudanca.oQueMuda, 'a chave e o endereço');
    });

    test('só a chave nova não promete mexer no endereço', () {
      // A confirmacao repete este texto. Prometer endereco onde so a chave muda
      // ensina o produtor a nao ler o aviso.
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 7,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-velha',
        idHardwareAtual: 'ESP32_215788',
        enderecoNovo: '192.168.0.50',
        chaveNova: 'chave-NOVA-do-aparelho',
        idHardwareNovo: null,
      );

      expect(mudanca!.oQueMuda, 'a chave');
      expect(mudanca.mudaEndereco, isFalse);
      // O id do aparelho nao veio, e nao pode sumir por isso.
      expect(mudanca.idHardware, 'ESP32_215788');
    });

    test('nada diferente devolve nulo, em vez de uma gravação vazia', () {
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 7,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-velha',
        idHardwareAtual: 'ESP32_215788',
        enderecoNovo: '192.168.0.50',
        chaveNova: 'chave-velha',
        idHardwareNovo: 'ESP32_215788',
      );

      expect(mudanca, isNull);
    });

    test('convite sem chave não apaga a chave que está guardada', () {
      // Um convite pode vir sem chave (estufa sem chave configurada). Vazio ali
      // significa "nao veio nada", nunca "apague o que esta la" - e apagar
      // derrubaria os comandos da estufa.
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 7,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-velha',
        idHardwareAtual: 'ESP32_215788',
        enderecoNovo: 'sentinela-215788.local',
        chaveNova: null,
        idHardwareNovo: null,
      );

      expect(mudanca!.mudaChave, isFalse);
      expect(mudanca.chave, 'chave-velha');
      expect(mudanca.oQueMuda, 'o endereço');
    });

    test('o nome da estufa é o que já estava lá, não o do convite', () {
      // Atualizar a chave nao e pedir para renomear: o nome e escolha de cada
      // celular, e o app respeita isso ate nas notificacoes.
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 7,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-velha',
        idHardwareAtual: null,
        enderecoNovo: '192.168.0.51',
        chaveNova: null,
        idHardwareNovo: 'ESP32_215788',
      );

      expect(mudanca!.nome, 'Estufa do Fundo');
      // Estufa cadastrada a mao, sem id, aprende o dele agora.
      expect(mudanca.idHardware, 'ESP32_215788');
    });
  });

  group('o formulário diante de um convite do aparelho já cadastrado', () {
    late _RepositorioFalso repositorio;
    late ResultadoFormEstufa? resultado;

    setUp(() {
      repositorio = _RepositorioFalso([jaCadastrada]);
      resultado = null;
    });

    /// Abre o formulario como a home abre: numa rota propria, para o resultado
    /// devolvido ao fechar ser o mesmo que ela le.
    Future<void> abrir(
      WidgetTester tester, {
      ConviteEstufa? comConvite,
    }) async {
      // O formulario tem ~1.000 px de conteudo; numa janela padrao o botao
      // "Salvar" ficaria fora da tela e o toque nao encontraria alvo.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await Navigator.of(context)
                      .push<ResultadoFormEstufa>(
                        MaterialPageRoute(
                          builder: (_) => EstufaFormScreen(
                            convite: comConvite,
                            repositorio: repositorio,
                          ),
                        ),
                      );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> salvar(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
    }

    testWidgets('oferece atualizar, dizendo qual estufa e o que muda', (
      tester,
    ) async {
      await abrir(tester, comConvite: convite);
      await salvar(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      // QUAL estufa: sem o nome, o produtor com duas estufas nao tem como saber
      // em qual esta prestes a mexer.
      expect(find.text('Atualizar "Estufa do Fundo"?'), findsOneWidget);
      // O QUE muda, e nao um "OK?" generico.
      expect(
        find.text('Atualizar a chave e o endereço'),
        findsOneWidget,
      );
      expect(
        find.textContaining('para de responder até alguém ir até ele'),
        findsOneWidget,
        reason: 'o custo de aceitar por engano tem de estar escrito',
      );
      // E nao a recusa de antes.
      expect(find.textContaining('Cadastrar de novo criaria'), findsNothing);
    });

    testWidgets('recusar a confirmação não grava NADA', (tester) async {
      await abrir(tester, comConvite: convite);
      await salvar(tester);

      // Ancorado no dialogo de proposito: o formulario tem um "Cancelar"
      // proprio atras dele, e um toque nesse passaria como recusa sem nunca ter
      // tocado no dialogo — o teste passaria sem provar nada.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Cancelar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      // O teste que decide se isto presta: chave sobrescrita sem um "sim"
      // explicito tira o acesso do produtor ate ele ir ate o aparelho.
      expect(repositorio.atualizacoes, isEmpty);
      expect(repositorio.salvamentos, isEmpty);
      // E o formulario continua aberto, com o convite na mao.
      expect(find.byType(EstufaFormScreen), findsOneWidget);
      expect(resultado, isNull);
    });

    testWidgets('confirmar atualiza a estufa que já existe, sem criar outra', (
      tester,
    ) async {
      await abrir(tester, comConvite: convite);
      await salvar(tester);

      await tester.tap(find.text('Atualizar a chave e o endereço'));
      await tester.pumpAndSettle();

      expect(repositorio.salvamentos, isEmpty, reason: 'nada de estufa nova');
      expect(repositorio.atualizacoes, hasLength(1));
      final gravado = repositorio.atualizacoes.single;
      expect(gravado.id, 7, reason: 'a estufa que ja existia, e nao outra');
      expect(gravado.chave, 'chave-NOVA-do-aparelho');
      expect(gravado.ip, 'sentinela-215788.local');
      expect(gravado.idHardware, 'ESP32_215788');
      expect(gravado.nome, 'Estufa do Fundo');

      // A home anuncia atualizacao, e nao cadastro: nenhuma estufa nasceu.
      expect(resultado, ResultadoFormEstufa.atualizada);
    });

    testWidgets('convite igual ao que já está gravado não pede confirmação', (
      tester,
    ) async {
      repositorio = _RepositorioFalso([
        const ModeloEstufa(
          id: 7,
          nome: 'Estufa do Fundo',
          ip: 'sentinela-215788.local',
          tokenAcesso: 'chave-NOVA-do-aparelho',
          idHardware: 'ESP32_215788',
        ),
      ]);
      await abrir(tester, comConvite: convite);
      await salvar(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(repositorio.atualizacoes, isEmpty);
      expect(find.textContaining('Não há o que atualizar'), findsOneWidget);
    });

    testWidgets('o caminho de "Colar convite" chega na mesma oferta', (
      tester,
    ) async {
      // Se a oferta ficasse so no QR, a assimetria que motivou a lacuna 1 se
      // repetiria — um caminho resolve, o outro recusa, na mesma situacao.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          if (chamada.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': convite.codificar()};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await abrir(tester);
      await tester.tap(find.text('Colar convite'));
      await tester.pumpAndSettle();
      await salvar(tester);

      expect(find.text('Atualizar "Estufa do Fundo"?'), findsOneWidget);

      await tester.tap(find.text('Atualizar a chave e o endereço'));
      await tester.pumpAndSettle();

      expect(repositorio.atualizacoes, hasLength(1));
      expect(repositorio.atualizacoes.single.chave, 'chave-NOVA-do-aparelho');
    });

    testWidgets('digitado à mão, sem convite, a recusa continua valendo', (
      tester,
    ) async {
      // Sem convite nao ha autoridade para mexer numa estufa que funciona, e a
      // recusa de sempre vale. O conflito alcancavel a mao e o de ENDERECO: o
      // campo de id saiu da tela, entao apontar duas estufas ao mesmo aparelho
      // por id digitado deixou de ser possivel — fechado por construcao, e nao
      // por guarda.
      await abrir(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Estufa Nova');
      await tester.enterText(find.byType(TextField).at(1), '192.168.0.50');
      await tester.pump();

      await salvar(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(repositorio.atualizacoes, isEmpty);
      expect(repositorio.salvamentos, isEmpty);
      expect(
        find.textContaining('já usa este endereço'),
        findsOneWidget,
      );
    });

    testWidgets('a tela de cadastro não pede chave nem id', (tester) async {
      // O que substituiu a recusa por id: nao ha onde digitar um. Os tres
      // caminhos de entrada preenchem os dois sozinhos.
      await abrir(tester);

      expect(find.text('Chave de acesso'), findsNothing);
      expect(find.text('ID do aparelho'), findsNothing);
      expect(find.text('Opções avançadas'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });
}

/// Repositorio de mentira: guarda o que foi pedido, sem banco e sem rede.
///
/// O que estes testes conferem e exatamente o que ele registra — se uma chave
/// foi gravada, e qual. Com o Isar de verdade no meio, isso so seria conferido
/// com dois celulares na mao.
class _RepositorioFalso extends EstufasRepository {
  _RepositorioFalso(this._estufas) : super(IsarService.instance);

  final List<ModeloEstufa> _estufas;
  final List<
    ({int id, String nome, String ip, String? chave, String? idHardware})
  >
  atualizacoes = [];
  final List<String> salvamentos = [];

  @override
  Future<List<ModeloEstufa>> listar() async => _estufas;

  @override
  Future<void> atualizar({
    required int id,
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    atualizacoes.add((
      id: id,
      nome: nome,
      ip: ip,
      chave: tokenAcesso,
      idHardware: idHardware,
    ));
  }

  @override
  Future<void> salvar({
    required String nome,
    required String ip,
    String? tokenAcesso,
    String? idHardware,
  }) async {
    salvamentos.add(nome);
  }
}
