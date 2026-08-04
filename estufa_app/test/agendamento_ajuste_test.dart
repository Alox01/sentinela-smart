import 'package:estufa_app/features/agendamento/models/agendamento_ajuste.dart';
import 'package:estufa_app/features/agendamento/services/agendamento_service.dart';
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
  testesDePendentes();

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

/// A regra de quem ainda vale uma tentativa de registro na nuvem.
///
/// Fica separada do resto do [AgendamentoService] de propósito: é a única parte
/// de `reenviarPendentes` que decide alguma coisa. O resto é plugin de
/// notificação, disco e rede — nada disso existe num teste, e foi por isso que
/// o serviço passou tanto tempo sem nenhum.
void testesDePendentes() {
  final agora = DateTime(2026, 8, 4, 20);

  AgendamentoAjuste ag({
    required int idLocal,
    String? id,
    String? idHardware = 'ESP32_ABC',
    required DateTime quando,
  }) => AgendamentoAjuste(
    id: id,
    idLocal: idLocal,
    idEstufa: 1,
    nomeEstufa: 'Esp32-1',
    idHardware: idHardware,
    quando: quando,
    temperaturaMeta: 130,
  );

  group('pendentes de registro na nuvem', () {
    test('o que está no futuro e sem id na nuvem entra', () {
      final lista = [
        ag(idLocal: 1, quando: agora.add(const Duration(hours: 3))),
      ];

      expect(pendentesDeRegistroNaNuvem(lista, agora).single.idLocal, 1);
    });

    test('o que já foi registrado fica de fora', () {
      // Reenviar criaria um segundo agendamento na nuvem para o mesmo ajuste, e
      // a estufa mudaria duas vezes.
      final lista = [
        ag(
          idLocal: 1,
          id: 'ja-esta-la',
          quando: agora.add(const Duration(hours: 3)),
        ),
      ];

      expect(pendentesDeRegistroNaNuvem(lista, agora), isEmpty);
    });

    test('sem idHardware fica de fora', () {
      // Não há a quem amarrar o ajuste; a nuvem recusaria e a tentativa só
      // gastaria requisição.
      final lista = [
        ag(
          idLocal: 1,
          idHardware: null,
          quando: agora.add(const Duration(hours: 3)),
        ),
      ];

      expect(pendentesDeRegistroNaNuvem(lista, agora), isEmpty);
    });

    test('o que já passou da hora fica de fora', () {
      // É o caso perigoso: registrar às 5h um ajuste marcado para as 3h faria a
      // nuvem mexer na estufa quando ninguém mais espera por isso.
      final lista = [
        ag(idLocal: 1, quando: agora.subtract(const Duration(hours: 2))),
      ];

      expect(pendentesDeRegistroNaNuvem(lista, agora), isEmpty);
    });

    test('a hora exata não conta como futuro', () {
      // `isAfter` é estrito, e é o que se quer: vencido é vencido.
      final lista = [ag(idLocal: 1, quando: agora)];

      expect(pendentesDeRegistroNaNuvem(lista, agora), isEmpty);
    });

    test('separa os que valem dos que não valem, na mesma lista', () {
      final lista = [
        ag(idLocal: 1, quando: agora.add(const Duration(hours: 1))),
        ag(idLocal: 2, id: 'x', quando: agora.add(const Duration(hours: 2))),
        ag(idLocal: 3, quando: agora.subtract(const Duration(hours: 1))),
        ag(
          idLocal: 4,
          idHardware: null,
          quando: agora.add(const Duration(hours: 4)),
        ),
        ag(idLocal: 5, quando: agora.add(const Duration(days: 1))),
      ];

      expect(
        pendentesDeRegistroNaNuvem(lista, agora).map((a) => a.idLocal),
        [1, 5],
      );
    });
  });
}
