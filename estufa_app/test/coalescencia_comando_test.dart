import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:estufa_app/services/coalescencia_comando.dart';

void main() {
  group('chaveCoalescenciaComando', () {
    test('comando de temperatura usa a chave temperaturaMeta', () {
      expect(
        chaveCoalescenciaComando({'temperaturaMeta': 95.0}),
        'temperaturaMeta',
      );
    });

    test('comando de umidade usa a chave umidadeMeta', () {
      expect(chaveCoalescenciaComando({'umidadeMeta': 80.0}), 'umidadeMeta');
    });

    test('silenciar (por campo ou por comando) usa a chave modoSilencioso', () {
      expect(
        chaveCoalescenciaComando({'modoSilencioso': true}),
        'modoSilencioso',
      );
      expect(
        chaveCoalescenciaComando({'comando': 'silenciar'}),
        'modoSilencioso',
      );
    });

    test('comando sem campo conhecido nao coalesce (retorna null)', () {
      expect(chaveCoalescenciaComando({'comando': 'reiniciar'}), isNull);
      expect(chaveCoalescenciaComando({}), isNull);
    });

    test('dois ajustes do mesmo campo compartilham a chave (o novo vence)', () {
      // Mesmo campo, valores diferentes -> mesma chave: o comando mais novo
      // remove o antigo da fila (Last-Write-Wins do lado do app).
      final antigo = chaveCoalescenciaComando({'temperaturaMeta': 90.0});
      final novo = chaveCoalescenciaComando({'temperaturaMeta': 110.0});
      expect(antigo, equals(novo));
    });

    test('campos diferentes nao coalescem entre si', () {
      expect(
        chaveCoalescenciaComando({'temperaturaMeta': 90.0}),
        isNot(chaveCoalescenciaComando({'umidadeMeta': 90.0})),
      );
    });
  });

  group('chaveCoalescenciaPayloadJson', () {
    test('reconhece a chave a partir do payload serializado', () {
      final json = jsonEncode({'temperaturaMeta': 100.0});
      expect(chaveCoalescenciaPayloadJson(json), 'temperaturaMeta');
    });

    test('JSON invalido retorna null (nao quebra a fila)', () {
      expect(chaveCoalescenciaPayloadJson('nao-e-json'), isNull);
    });

    test('JSON que nao e objeto retorna null', () {
      expect(chaveCoalescenciaPayloadJson('[1, 2, 3]'), isNull);
    });
  });
}
