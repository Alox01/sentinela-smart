import 'package:estufa_app/features/home/models/modelo_estufa.dart';
import 'package:estufa_app/features/home/services/estufas_repository.dart';
import 'package:estufa_app/screens/estufa_form_screen.dart';
import 'package:estufa_app/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Editar uma estufa que ja existe — o caminho mais usado do formulario, e o
/// unico que nunca teve teste.
void main() {
  const existente = ModeloEstufa(
    id: 7,
    nome: 'Estufa 1',
    ip: 'sentinela-215788.local',
    tokenAcesso: 'chave-do-aparelho',
    idHardware: 'ESP32_215788',
  );

  testWidgets('salvar sem mudar nada atualiza e fecha a tela', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repositorio = _RepositorioFalso([existente]);
    ResultadoFormEstufa? resultado;

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
                          estufa: existente,
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

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    // O que o produtor viu: a tela nao fechou e apareceu "nao foi possivel".
    expect(
      find.textContaining('Não foi possível salvar'),
      findsNothing,
      reason: 'salvar uma edicao sem conflito nao pode falhar',
    );
    expect(find.byType(EstufaFormScreen), findsNothing, reason: 'tem de fechar');
    expect(repositorio.atualizacoes, hasLength(1));
    expect(resultado, ResultadoFormEstufa.atualizada);
  });

  // O defeito que isto guarda: "Cancelar" devolvia `false` numa rota tipada
  // ResultadoFormEstufa. A conversao estourava DEPOIS de a rota ja estar
  // marcada como fechada, e a tela ficava presa — sem voltar, sem cancelar, e
  // com todo salvar seguinte falhando com "No element".
  testWidgets('cancelar fecha a tela e não devolve resultado', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repositorio = _RepositorioFalso([existente]);
    ResultadoFormEstufa? resultado;
    var voltou = false;

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
                          estufa: existente,
                          repositorio: repositorio,
                        ),
                      ),
                    );
                voltou = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(EstufaFormScreen), findsNothing, reason: 'tem de fechar');
    expect(voltou, isTrue, reason: 'quem abriu precisa voltar a rodar');
    expect(resultado, isNull, reason: 'cancelar nao produz resultado');
    expect(repositorio.atualizacoes, isEmpty);
  });
}

class _RepositorioFalso extends EstufasRepository {
  _RepositorioFalso(this._estufas) : super(IsarService.instance);

  final List<ModeloEstufa> _estufas;
  final List<int> atualizacoes = [];

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
    atualizacoes.add(id);
  }
}
