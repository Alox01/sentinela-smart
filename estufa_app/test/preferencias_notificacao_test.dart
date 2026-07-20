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
}
