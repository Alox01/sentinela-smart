import 'package:estufa_app/features/aparelho/prefixo_da_rede.dart';
import 'package:flutter_test/flutter_test.dart';

/// Levar o aparelho para outra rede levando junto o IP fixo da rede de origem.
///
/// Aconteceu em campo: o aparelho foi para a faculdade, o app ofereceu a faixa
/// `192.168.1.` — o gateway aprendido em CASA —, o número foi completado, e o
/// aparelho passou a aplicar um endereço de outra rede. Ele associa no Wi-Fi
/// normalmente, mas fica sem gateway e sem DNS válidos: não alcança a nuvem
/// (SEM SINAL) e ninguém o alcança localmente. Nada dá erro.
///
/// O firmware hoje ignora IP fixo de outra faixa. Isto guarda a outra metade:
/// não oferecer o número errado em primeiro lugar.
void main() {
  const gatewayDeCasa = '192.168.1.1';
  const redeDeCasa = 'WiFi-Casa';

  test('mesma rede: oferece a faixa que o aparelho aprendeu', () {
    expect(
      prefixoOferecido(
        gatewayAprendido: gatewayDeCasa,
        ssidDoAparelho: redeDeCasa,
        ssidDigitado: redeDeCasa,
      ),
      '192.168.1.',
    );
  });

  test('outra rede: não oferece nada', () {
    // O caso da faculdade. Oferecer aqui é oferecer o endereço de outro lugar.
    expect(
      prefixoOferecido(
        gatewayAprendido: gatewayDeCasa,
        ssidDoAparelho: redeDeCasa,
        ssidDigitado: 'WiFi-Faculdade',
      ),
      isNull,
    );
  });

  test('espaços em volta do nome não contam como outra rede', () {
    expect(
      prefixoOferecido(
        gatewayAprendido: gatewayDeCasa,
        ssidDoAparelho: '  $redeDeCasa  ',
        ssidDigitado: redeDeCasa,
      ),
      '192.168.1.',
    );
  });

  test('aparelho que nunca entrou em rede nenhuma não ensina faixa', () {
    // Sem rede anterior não há gateway aprendido, e um palpite de faixa seria
    // exatamente o defeito que isto evita.
    expect(
      prefixoOferecido(
        gatewayAprendido: '',
        ssidDoAparelho: '',
        ssidDigitado: 'WiFi-Casa',
      ),
      isNull,
    );
  });

  test('gateway que não é endereço não vira faixa', () {
    expect(
      prefixoOferecido(
        gatewayAprendido: 'nao-e-ip',
        ssidDoAparelho: redeDeCasa,
        ssidDigitado: redeDeCasa,
      ),
      isNull,
    );
  });

  group('prefixoDe', () {
    test('corta os três primeiros números', () {
      expect(prefixoDe('10.0.0.7'), '10.0.0.');
      expect(prefixoDe('172.16.30.254'), '172.16.30.');
    });

    test('recusa o que não é IPv4', () {
      expect(prefixoDe(null), isNull);
      expect(prefixoDe('192.168.1'), isNull);
      expect(prefixoDe('192.168.1.a'), isNull);
    });
  });
}
