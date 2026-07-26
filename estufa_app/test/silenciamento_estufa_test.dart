import 'package:estufa_app/features/notificacoes/models/preferencias_notificacao.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regra do silenciamento por estufa: ele so DESLIGA avisos, nunca LIGA.
///
/// Incendio e sem comunicacao continuam avisando numa estufa silenciada, mas
/// apenas se o produtor nao os tiver desligado nas configuracoes gerais - o
/// escopo menor nao pode revogar a decisao do escopo maior. Esta e a mesma
/// montagem feita em `PushNotificationService._prefsParaDispositivo`, isolada
/// aqui porque a de la depende de Firebase e de rede.
Map<String, dynamic> prefsParaEstufaSilenciada(PreferenciasNotificacao global) {
  final base = global.toJson();
  const sempreAvisam = {'incendio', 'temperaturaMuitoAlta', 'semComunicacao'};
  for (final chave in base.keys.toList()) {
    if (!sempreAvisam.contains(chave)) {
      base[chave] = {'notificar': false, 'tocarVibrar': false};
    }
  }
  return base;
}

bool notifica(Map<String, dynamic> prefs, EventoNotificacao evento) =>
    (prefs[evento.chave] as Map)['notificar'] == true;

void main() {
  group('estufa silenciada', () {
    test('mantem os avisos de risco quando o global os permite', () {
      final prefs = prefsParaEstufaSilenciada(PreferenciasNotificacao.padrao());
      expect(notifica(prefs, EventoNotificacao.incendio), isTrue);
      expect(notifica(prefs, EventoNotificacao.temperaturaMuitoAlta), isTrue);
      expect(notifica(prefs, EventoNotificacao.semComunicacao), isTrue);
    });

    test('cala os demais avisos daquela estufa', () {
      final prefs = prefsParaEstufaSilenciada(PreferenciasNotificacao.padrao());
      expect(notifica(prefs, EventoNotificacao.alarmeProcesso), isFalse);
    });

    test('nao religa o que o global desligou', () {
      // O produtor desligou incendio e sem comunicacao para TODAS as estufas.
      // Silenciar uma delas nao pode ressuscitar esses avisos.
      final global = PreferenciasNotificacao.padrao()
          .comEvento(
            EventoNotificacao.incendio,
            const OpcaoEvento(notificar: false, tocarVibrar: false),
          )
          .comEvento(
            EventoNotificacao.semComunicacao,
            const OpcaoEvento(notificar: false, tocarVibrar: false),
          );

      final prefs = prefsParaEstufaSilenciada(global);
      expect(notifica(prefs, EventoNotificacao.incendio), isFalse);
      expect(notifica(prefs, EventoNotificacao.semComunicacao), isFalse);
    });

    test('respeita o global evento a evento', () {
      // So o incendio segue ligado no global.
      final global = PreferenciasNotificacao.padrao().comEvento(
        EventoNotificacao.semComunicacao,
        const OpcaoEvento(notificar: false, tocarVibrar: false),
      );

      final prefs = prefsParaEstufaSilenciada(global);
      expect(notifica(prefs, EventoNotificacao.incendio), isTrue);
      expect(notifica(prefs, EventoNotificacao.semComunicacao), isFalse);
    });
  });
}
