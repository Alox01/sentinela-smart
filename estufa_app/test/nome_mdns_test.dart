import 'package:estufa_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// O aparelho se anuncia como `sentinela-xxxxxx.local`, mas diz o nome sem o
/// sufixo. Sem `.local` nao e nome mDNS: o sistema tenta DNS comum e nao acha,
/// entao a conexao local nunca acontecia — e a nuvem funcionando escondia isso.
void main() {
  group('completar o nome mDNS', () {
    test('acrescenta .local ao nome do aparelho', () {
      expect(
        ApiService.completarNomeMdns('sentinela-215788'),
        'sentinela-215788.local',
      );
    });

    test('preserva a porta, pondo o sufixo antes dela', () {
      expect(
        ApiService.completarNomeMdns('sentinela-215788:3000'),
        'sentinela-215788.local:3000',
      );
    });

    test('nao mexe no nome que ja tem o sufixo', () {
      expect(
        ApiService.completarNomeMdns('sentinela-215788.local'),
        'sentinela-215788.local',
      );
    });

    // IP e endereco de outro tipo passam intactos: completar seria estragar.
    test('nao mexe em IP', () {
      expect(ApiService.completarNomeMdns('192.168.0.220'), '192.168.0.220');
    });

    test('nao mexe em endereco que nao e do aparelho', () {
      expect(ApiService.completarNomeMdns('estufa-de-casa'), 'estufa-de-casa');
    });
  });

  test('o endereco local resolve com o sufixo, mesmo cadastrado sem ele', () {
    final api = ApiService('sentinela-215788');
    expect(api.localBaseUrl, 'http://sentinela-215788.local:3000');
  });
}
