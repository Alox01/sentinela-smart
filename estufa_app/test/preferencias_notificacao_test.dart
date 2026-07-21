import 'package:estufa_app/features/notificacoes/models/preferencias_notificacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('padrao liga tudo', () {
    final p = PreferenciasNotificacao.padrao();
    for (final e in EventoNotificacao.values) {
      expect(p.opcao(e).notificar, isTrue);
      expect(p.opcao(e).tocarVibrar, isTrue);
    }
  });

  test('comEvento nao muda os outros eventos', () {
    final p = PreferenciasNotificacao.padrao().comEvento(
      EventoNotificacao.alarmeProcesso,
      const OpcaoEvento(notificar: false, tocarVibrar: false),
    );
    expect(p.opcao(EventoNotificacao.alarmeProcesso).notificar, isFalse);
    expect(p.opcao(EventoNotificacao.incendio).notificar, isTrue);
  });

  test('serializa e desserializa de volta ao mesmo estado', () {
    final original = PreferenciasNotificacao.padrao()
        .comEvento(
          EventoNotificacao.incendio,
          const OpcaoEvento(notificar: true, tocarVibrar: false),
        )
        .comEvento(
          EventoNotificacao.semComunicacao,
          const OpcaoEvento(notificar: false, tocarVibrar: false),
        );

    final volta = PreferenciasNotificacao.fromJsonString(
      original.toJsonString(),
    );

    for (final e in EventoNotificacao.values) {
      expect(volta.opcao(e), original.opcao(e), reason: e.chave);
    }
  });

  test('texto invalido cai no padrao, nao quebra', () {
    expect(
      PreferenciasNotificacao.fromJsonString('nao e json').opcao(
        EventoNotificacao.incendio,
      ).notificar,
      isTrue,
    );
    expect(
      PreferenciasNotificacao.fromJsonString(null).opcao(
        EventoNotificacao.incendio,
      ).notificar,
      isTrue,
    );
  });

  test('incendio e o unico marcado como critico', () {
    for (final e in EventoNotificacao.values) {
      expect(e.critico, e == EventoNotificacao.incendio, reason: e.chave);
    }
  });

  // O evento separado de falta de energia foi removido de proposito: sem sensor
  // de tensao o aparelho nunca reporta `temEnergia=false`, entao ele nao podia
  // disparar. Pior, quem confiasse nele podia desligar "sem comunicacao" - o
  // aviso que de fato funciona - achando que estava coberto.
  test('nao existe evento separado de falta de energia', () {
    expect(
      EventoNotificacao.values.map((e) => e.chave),
      isNot(contains('faltaEnergia')),
    );
    expect(EventoNotificacao.values, hasLength(3));
  });

  test('preferencia antiga com faltaEnergia continua carregando', () {
    // Quem ja usava o app tem esta chave gravada no aparelho.
    const salvoAntigo =
        '{"alarmeProcesso":{"notificar":false,"tocarVibrar":false},'
        '"faltaEnergia":{"notificar":true,"tocarVibrar":true},'
        '"semComunicacao":{"notificar":false,"tocarVibrar":true}}';

    final p = PreferenciasNotificacao.fromJsonString(salvoAntigo);

    // A chave que sumiu e ignorada, e o resto e preservado.
    expect(p.opcao(EventoNotificacao.alarmeProcesso).notificar, isFalse);
    expect(p.opcao(EventoNotificacao.semComunicacao).notificar, isFalse);
    expect(p.opcao(EventoNotificacao.semComunicacao).tocarVibrar, isTrue);
  });
}
