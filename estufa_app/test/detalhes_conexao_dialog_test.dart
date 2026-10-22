import 'package:estufa_app/features/monitoramento/dialogs/detalhes_conexao_dialog.dart';
import 'package:estufa_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rotulo e modo nao ficam grudados em tela estreita', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final conhecido = ResultadoAlcance(
      probes: const [
        ApiConnectionProbe(
          baseUrl: 'http://192.168.1.20',
          nome: 'Local',
          online: true,
        ),
        ApiConnectionProbe(
          baseUrl: 'https://nuvem.exemplo',
          nome: 'Nuvem',
          online: true,
        ),
      ],
      quando: DateTime.now(),
    );
    final alcance = ValueNotifier<ResultadoAlcance?>(conhecido);
    final atualizacoes = ValueNotifier<int>(0);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarDetalhesConexaoDialog(
              context: context,
              modoConexaoAtual: () => 'LOCAL',
              atualizacoesConexao: atualizacoes,
              idHardware: 'ESP32_TESTE',
              totalPendencias: 0,
              pendencias: const [],
              alcanceConhecido: conhecido,
              alcanceAtual: alcance,
              testarAlcance: () async => conhecido.probes,
              sincronizandoPendencias: false,
              onLimparFila: () {},
              onSincronizar: () {},
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final rotulo = tester.getRect(find.text('Conexão usada agora'));
    final valor = tester.getRect(find.text('LOCAL'));
    expect(valor.left - rotulo.right, greaterThanOrEqualTo(12));
    expect(find.text('Aparelho local: disponível'), findsOneWidget);
    expect(find.text('Servidor na nuvem: disponível'), findsOneWidget);
    expect(find.text('Aparelho (id)'), findsOneWidget);
    expect(find.text('ESP32_TESTE'), findsOneWidget);
    expect(find.text('Detalhes técnicos'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
