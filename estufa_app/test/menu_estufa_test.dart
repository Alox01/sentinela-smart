import 'package:estufa_app/features/monitoramento/widgets/itens_menu_estufa.dart';
import 'package:estufa_app/features/monitoramento/widgets/menu_estufa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Inventário da gaveta da estufa.
///
/// ## Por que este teste existe
///
/// A gaveta saiu de `monitoramento_screen.dart` para `MenuEstufa`. A prova de
/// que nenhum item sumiu foi feita por leitura e diff, duas vezes, por pessoas
/// diferentes — e isso não sobrevive à próxima mudança. O modo de falha desta
/// área é **um item desaparecer em silêncio**: a gaveta continua abrindo, nada
/// fica vermelho, `flutter analyze` fica limpo, e só o produtor descobre, em
/// campo, que não dá mais para silenciar aquela estufa.
///
/// Então o teste não confere "existe um item chamado X" — isso passaria com os
/// itens embaralhados ou com um deles em outra seção. Ele monta a lista inteira
/// das posições, na ordem, e compara com a esperada.
///
/// Uma posição some DE PROPÓSITO: "Avisos no celular" só existe quando este
/// celular não vai ser avisado. Estar tudo certo é o caso comum, e anunciá-lo
/// para quem não sabe o que é uma inscrição de push só levantava dúvida. O
/// inventário normal tem 16 linhas por isso — e há um teste só para provar que
/// a 17ª volta quando há problema, senão esta economia viraria justamente o item
/// sumindo em silêncio que o arquivo inteiro existe para impedir.
///
/// ## Os três *singletons*
///
/// `MenuEstufa` toca `SilenciamentoEstufas`, `PreferenciasNotificacaoService` e
/// `PushNotificationService`, e nenhum deles está inicializado num teste de
/// widget. **Nada foi mudado na produção por causa disso**, porque os três já
/// se comportam bem sem inicialização:
///
/// - `SilenciamentoEstufas.instance.silenciada(id)` é uma consulta a um `Set` em
///   memória, vazio até alguém chamar `carregar()`. Responde `false`, sem
///   plugin.
/// - `PreferenciasNotificacaoService.instance.preferencias` devolve
///   `PreferenciasNotificacao.padrao()` enquanto não carregou. Sem plugin.
/// - `PushNotificationService` só é alcançado dentro do `onChanged` do
///   interruptor de silenciar (`atualizarPreferenciasDispositivo`), que este
///   teste não dispara. Nenhum `build` o toca.
///
/// Nenhum dos dois primeiros chama `SharedPreferences` durante o `build`, então
/// não há canal de plataforma para fingir e não há `carregar()` a esperar.
///
/// O risco que sobra é o descrito no enunciado: **passar por acidente**. Um
/// *singleton* meio inicializado poderia fazer o item de silenciar desenhar uma
/// casca vazia, e a contagem continuaria batendo. Por isso o teste também afirma
/// a legenda que só existe se os dois *singletons* tiverem sido lidos de verdade
/// — ver `legenda do silenciar prova que os singletons responderam`.
///
/// Este arquivo não toca no estado dos *singletons* (não chama `carregar()` nem
/// `definir()`), para não deixar estado global sujo para os testes seguintes.
void main() {
  // A gaveta tem ~1.200 px de conteúdo. Numa janela de teste padrão (600 px) o
  // `ListView` construiria só os primeiros itens e o inventário sairia curto —
  // falha por preguiça de layout, que se pareceria com item sumido. Uma janela
  // alta faz todos existirem de fato.
  void janelaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<List<String>> abrirGaveta(
    WidgetTester tester,
    DadosMenuEstufa dados,
  ) async {
    janelaAlta(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Mesmo lugar em que a tela de monitoramento a pendura.
          endDrawer: MenuEstufa(dados: dados, acoes: _acoesInertes),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
    await tester.pumpAndSettle();
    return _inventario(tester);
  }

  group('inventário da gaveta', () {
    testWidgets('16 posições, na ordem, com o aparelho ainda calado', (
      tester,
    ) async {
      // Tudo o que o aparelho ainda não informou vem `null`: é o estado em que a
      // gaveta abre logo depois de entrar na tela.
      final inventario = await abrirGaveta(tester, _dadosBase);

      expect(inventario, [
        'cabeçalho: Estufa do Fundo + AÇÕES',
        'divisor',
        'seção: CONEXÃO',
        'item: Detalhes da conexão',
        'item: Configurar aparelho',
        'item: Compartilhar acesso',
        'item: Tirar acesso dos outros celulares',
        'divisor',
        'seção: AVISOS',
        'item: Silenciar avisos',
        // Sem "Avisos no celular": `vigiada` é `null` (ainda conferindo), e a
        // linha só aparece no caso `false`.
        'item: Sirene do aparelho',
        'divisor',
        'seção: AÇÕES RÁPIDAS',
        'item: Agendar ajuste',
        'item: Reiniciar ajustes do aparelho',
        'item: Apagar estufadas',
      ]);
    });

    testWidgets('as mesmas 16 posições com o aparelho já reportando', (
      tester,
    ) async {
      // Dois itens trocam de título conforme o estado, e um `switch` que ganhe um
      // caso a menos sumiria com o item. Aqui o aparelho já falou (sirene ligada,
      // celular inscrito) e ainda não tem `idHardware` — o interruptor de
      // silenciar nasce desabilitado, mas continua na lista.
      final inventario = await abrirGaveta(
        tester,
        _dados(idHardware: null, vigiada: true, buzzerAparelhoAtivo: true),
      );

      expect(inventario, [
        'cabeçalho: Estufa do Fundo + AÇÕES',
        'divisor',
        'seção: CONEXÃO',
        'item: Detalhes da conexão',
        'item: Configurar aparelho',
        'item: Compartilhar acesso',
        'item: Tirar acesso dos outros celulares',
        'divisor',
        'seção: AVISOS',
        'item: Silenciar avisos',
        // Inscrito: continua fora. Era aqui que a linha dizia "ativos".
        'item: Sirene do aparelho: ligada',
        'divisor',
        'seção: AÇÕES RÁPIDAS',
        'item: Agendar ajuste',
        'item: Reiniciar ajustes do aparelho',
        'item: Apagar estufadas',
      ]);
    });

    testWidgets('a 17ª posição volta quando o celular não será avisado', (
      tester,
    ) async {
      // O contrário dos dois acima, e a razão de o item existir: uma estufa não
      // inscrita é idêntica a uma inscrita na tela, e foi assim que um aparelho
      // ficou 24 h fora do ar sem nenhum aviso sair. Esconder no caso bom só se
      // paga se o caso ruim aparecer.
      final inventario = await abrirGaveta(
        tester,
        _dados(vigiada: false, buzzerAparelhoAtivo: true),
      );

      expect(inventario, [
        'cabeçalho: Estufa do Fundo + AÇÕES',
        'divisor',
        'seção: CONEXÃO',
        'item: Detalhes da conexão',
        'item: Configurar aparelho',
        'item: Compartilhar acesso',
        'item: Tirar acesso dos outros celulares',
        'divisor',
        'seção: AVISOS',
        'item: Silenciar avisos',
        'item: Este celular não será avisado',
        'item: Sirene do aparelho: ligada',
        'divisor',
        'seção: AÇÕES RÁPIDAS',
        'item: Agendar ajuste',
        'item: Reiniciar ajustes do aparelho',
        'item: Apagar estufadas',
      ]);
    });
  });

  group('as três seções', () {
    testWidgets('aparecem uma vez cada, nesta ordem', (tester) async {
      final inventario = await abrirGaveta(tester, _dadosBase);

      expect(
        inventario.where((linha) => linha.startsWith('seção: ')).toList(),
        ['seção: CONEXÃO', 'seção: AVISOS', 'seção: AÇÕES RÁPIDAS'],
      );
      expect(find.byType(TituloMenu), findsNWidgets(3));
    });

    testWidgets('cada item está sob a seção certa', (tester) async {
      final inventario = await abrirGaveta(tester, _dadosBase);

      String secaoDe(String item) {
        final fim = inventario.indexOf(item);
        expect(fim, isNot(-1), reason: 'sumiu do menu: $item');
        return inventario
            .take(fim)
            .lastWhere((l) => l.startsWith('seção: '), orElse: () => 'nenhuma');
      }

      expect(secaoDe('item: Detalhes da conexão'), 'seção: CONEXÃO');
      expect(secaoDe('item: Configurar aparelho'), 'seção: CONEXÃO');

      expect(secaoDe('item: Silenciar avisos'), 'seção: AVISOS');
      expect(secaoDe('item: Sirene do aparelho'), 'seção: AVISOS');
      // Compartilhar e tirar acesso ficam em CONEXÃO desde 05/08/2026. Moravam
      // em AVISOS — posição herdada da tela antiga e preservada sem discussão
      // quando a gaveta foi extraída. Os dois decidem QUEM COMANDA a estufa, o
      // que não é assunto de aviso, e ficam juntos porque um desfaz o outro.
      expect(secaoDe('item: Compartilhar acesso'), 'seção: CONEXÃO');
      expect(
        secaoDe('item: Tirar acesso dos outros celulares'),
        'seção: CONEXÃO',
      );

      expect(secaoDe('item: Agendar ajuste'), 'seção: AÇÕES RÁPIDAS');
      expect(
        secaoDe('item: Reiniciar ajustes do aparelho'),
        'seção: AÇÕES RÁPIDAS',
      );
      expect(secaoDe('item: Apagar estufadas'), 'seção: AÇÕES RÁPIDAS');

      // O cabeçalho vem antes de qualquer seção.
      expect(inventario.first, startsWith('cabeçalho: '));
    });
  });

  testWidgets('legenda do silenciar prova que os singletons responderam', (
    tester,
  ) async {
    // Guarda contra o teste "passar por acidente": esta frase só sai se
    // `SilenciamentoEstufas` tiver dito que a estufa não está silenciada E
    // `PreferenciasNotificacaoService` tiver entregue as preferências padrão
    // (incêndio e sem comunicação ligados). Um item de silenciar que desenhasse
    // uma casca vazia manteria a contagem de 16 e morreria aqui.
    await abrirGaveta(tester, _dadosBase);

    expect(
      find.text('Incêndio e sem comunicação continuam avisando.'),
      findsOneWidget,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });
}

// ---------------------------------------------------------------------------

/// A tela é quem faz estas três coisas; aqui elas só precisam existir.
final _acoesInertes = AcoesMenuEstufa(
  aoAbrirDetalhesConexao: () {},
  aoConfigurarAparelho: () {},
  aoTirarAcessoDosOutros: () {},
  aoReiniciarAjustes: () {},
);

DadosMenuEstufa _dados({
  String? idHardware = 'AABBCCDDEEFF',
  bool? vigiada,
  bool? buzzerAparelhoAtivo,
}) => DadosMenuEstufa(
  idEstufa: 7,
  nomeEstufa: 'Estufa do Fundo',
  ipEstufa: '192.168.0.50',
  tokenAcesso: 'chave-de-teste',
  idHardware: idHardware,
  temperaturaAjuste: 130,
  umidadeAjuste: 45,
  buzzerAparelhoAtivo: buzzerAparelhoAtivo,
  vigiada: vigiada,
  temperaturaNovaEstufada: 95,
  umidadeNovaEstufada: 60,
);

final _dadosBase = _dados();

/// Lê a gaveta desenhada e devolve uma linha por posição, de cima para baixo.
///
/// Percorre a árvore de elementos a partir do `ListView` e **para de descer**
/// assim que reconhece uma posição — sem isso o `SwitchListTile` apareceria duas
/// vezes (ele constrói um `ListTile` por dentro) e a contagem mentiria.
List<String> _inventario(WidgetTester tester) {
  final linhas = <String>[];

  void visitar(Element elemento) {
    final widget = elemento.widget;
    if (widget is Divider) {
      linhas.add('divisor');
      return;
    }
    if (widget is TituloMenu) {
      linhas.add('seção: ${widget.texto}');
      return;
    }
    if (widget is SwitchListTile) {
      linhas.add('item: ${_titulo(widget.title)}');
      return;
    }
    if (widget is ListTile) {
      linhas.add('item: ${_titulo(widget.title)}');
      return;
    }
    // Único `Column` dentro do `ListView` — as demais posições já pararam a
    // descida acima, e a maquinaria do `Scrollable` não tem coluna nenhuma.
    if (widget is Column) {
      linhas.add('cabeçalho: ${_textosDe(elemento).join(' + ')}');
      return;
    }
    elemento.visitChildren(visitar);
  }

  visitar(tester.element(find.byType(ListView)));
  return linhas;
}

String _titulo(Widget? titulo) =>
    titulo is Text ? (titulo.data ?? '(texto montado)') : '(sem Text no título)';

List<String> _textosDe(Element raiz) {
  final textos = <String>[];
  void coletar(Element elemento) {
    final widget = elemento.widget;
    if (widget is Text && widget.data != null) textos.add(widget.data!);
    elemento.visitChildren(coletar);
  }

  raiz.visitChildren(coletar);
  return textos;
}
