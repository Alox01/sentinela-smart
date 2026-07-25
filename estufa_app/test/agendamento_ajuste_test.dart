import 'package:estufa_app/features/agendamento/models/agendamento_ajuste.dart';
import 'package:flutter_test/flutter_test.dart';

AgendamentoAjuste criar({
  String? id,
  double? temperaturaMeta,
  double? temperaturaDelta,
  double? umidadeMeta,
  double? umidadeDelta,
}) => AgendamentoAjuste(
  id: id,
  idLocal: 42,
  idEstufa: 1,
  nomeEstufa: 'Esp32-1',
  idHardware: 'ESP32_ABC',
  quando: DateTime.fromMillisecondsSinceEpoch(1800000000000),
  temperaturaMeta: temperaturaMeta,
  temperaturaDelta: temperaturaDelta,
  umidadeMeta: umidadeMeta,
  umidadeDelta: umidadeDelta,
);

void main() {
  group('descricao', () {
    test('valor absoluto diz para quanto vai', () {
      expect(
        criar(temperaturaMeta: 120).descricao,
        'temperatura para 120°F',
      );
    });

    test('variacao positiva mostra o sinal', () {
      expect(criar(temperaturaDelta: 10).descricao, 'temperatura +10°F');
    });

    test('variacao negativa mostra o sinal', () {
      expect(criar(temperaturaDelta: -15).descricao, 'temperatura -15°F');
    });

    test('temperatura e umidade aparecem juntas', () {
      expect(
        criar(temperaturaMeta: 120, umidadeDelta: -10).descricao,
        'temperatura para 120°F e umidade -10%',
      );
    });
  });

  group('registradoNaNuvem', () {
    // Sem id do servidor o alvo NAO muda sozinho: so o aviso local acontece.
    // A tela usa isso para nao prometer o que nao vai cumprir.
    test('e falso sem id do servidor', () {
      expect(criar(temperaturaMeta: 120).registradoNaNuvem, isFalse);
    });

    test('e verdadeiro com id do servidor', () {
      expect(criar(id: '7', temperaturaMeta: 120).registradoNaNuvem, isTrue);
    });

    test('comId promove um agendamento so-local', () {
      final local = criar(temperaturaMeta: 120);
      final naNuvem = local.comId('9');
      expect(naNuvem.registradoNaNuvem, isTrue);
      expect(naNuvem.idLocal, local.idLocal);
      expect(naNuvem.temperaturaMeta, 120);
    });
  });

  group('serializacao', () {
    test('ida e volta preserva o agendamento', () {
      final original = criar(
        id: '3',
        temperaturaDelta: 10,
        umidadeMeta: 40,
      );
      final volta = AgendamentoAjuste.listaDeJson(
        AgendamentoAjuste.listaParaJson([original]),
      );
      expect(volta.length, 1);
      expect(volta.first.id, '3');
      expect(volta.first.idLocal, original.idLocal);
      expect(volta.first.quando, original.quando);
      expect(volta.first.temperaturaDelta, 10);
      expect(volta.first.umidadeMeta, 40);
      expect(volta.first.temperaturaMeta, isNull);
    });

    // Preferencia corrompida nao pode impedir o app de abrir.
    test('texto invalido devolve lista vazia em vez de quebrar', () {
      expect(AgendamentoAjuste.listaDeJson('nao e json'), isEmpty);
      expect(AgendamentoAjuste.listaDeJson('{"nao":"lista"}'), isEmpty);
      expect(AgendamentoAjuste.listaDeJson(null), isEmpty);
      expect(AgendamentoAjuste.listaDeJson(''), isEmpty);
    });
  });
}
