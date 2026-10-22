import 'package:estufa_app/services/identidade_aparelho.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migracao da identidade de 24 para 48 bits', () {
    test('aceita o MAC completo que termina no id legado', () {
      expect(
        ehMigracaoDeIdLegado('ESP32_215788', 'ESP32_AABBCC215788'),
        isTrue,
      );
      expect(idsDoMesmoAparelho('ESP32_215788', 'ESP32_AABBCC215788'), isTrue);
    });

    test('nao aceita outro sufixo como se fosse o mesmo aparelho', () {
      expect(
        ehMigracaoDeIdLegado('ESP32_215788', 'ESP32_AABBCC999999'),
        isFalse,
      );
      expect(idsDoMesmoAparelho('ESP32_215788', 'ESP32_AABBCC999999'), isFalse);
    });

    test('nao transforma troca entre dois ids completos em migracao', () {
      expect(
        ehMigracaoDeIdLegado('ESP32_AABBCC215788', 'ESP32_DDEEFF215788'),
        isFalse,
      );
    });
  });
}
