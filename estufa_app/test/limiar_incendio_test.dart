import 'package:estufa_app/features/monitoramento/limiar_incendio.dart';
import 'package:flutter_test/flutter_test.dart';

/// O limite de incêndio, do lado do app.
///
/// Existe porque a mesma regra vive em três linguagens — firmware, servidor e
/// aqui — e **já divergiu em campo**: o aparelho usava 175 fixo enquanto o
/// servidor acompanhava o ajuste, e com o ajuste em 172 a sirene tocava aos 175
/// e a nuvem só avisava aos 177. Os números abaixo são os mesmos exemplos que
/// `logica.js` e `limiteFogoF()` no firmware precisam responder.
void main() {
  test('na curva normal o limite é 175', () {
    // O ajuste da esmagadora maioria das estufadas fica bem abaixo de 170: aí
    // o limite não tem por que se mexer.
    expect(limiteFogoF(90), 175);
    expect(limiteFogoF(130), 175);
    expect(limiteFogoF(170), 175);
  });

  test('acima de 170 o limite acompanha o ajuste, com 5 de folga', () {
    // A cura que trabalha acima de 170: 175 fixo diria "incêndio" com a estufa
    // fazendo exatamente o que foi mandada fazer.
    expect(limiteFogoF(171), 176);
    expect(limiteFogoF(180), 185);
    expect(limiteFogoF(200), 205);
  });

  test('a virada é em 170, não em 171 nem em 175', () {
    // A fronteira exata importa: é onde as três implementações se separam se
    // alguém escrever `>=` no lugar de `>`.
    expect(limiteFogoF(170), 175);
    expect(limiteFogoF(170.5), closeTo(175.5, 0.001));
  });

  test('o limite nunca fica abaixo de 175', () {
    // Uma regra que baixasse o limite transformaria um ajuste baixo em alarme
    // de incêndio a 100 °F. Vale para qualquer ajuste plausível.
    for (var ajuste = 60.0; ajuste <= 220.0; ajuste += 5) {
      expect(
        limiteFogoF(ajuste),
        greaterThanOrEqualTo(175),
        reason: 'ajuste $ajuste baixou o limite de incêndio',
      );
    }
  });
}
