import 'package:flutter_test/flutter_test.dart';
import 'package:estufa_app/features/monitoramento/services/rastreador_conexao.dart';

void main() {
  const min = 60 * 1000;

  test('so registra queda apos 2 minutos offline, e uma vez so', () {
    final r = RastreadorConexao();
    expect(r.avaliarQueda(0), isFalse); // acabou de cair
    expect(r.avaliarQueda(1 * min), isFalse); // < 2 min
    expect(r.avaliarQueda(2 * min), isTrue); // completou 2 min
    expect(r.avaliarQueda(3 * min), isFalse); // nao repete
  });

  test('retorno so dispara se havia queda registrada, e reseta o ciclo', () {
    final r = RastreadorConexao();
    // sem queda registrada -> retorno nao dispara
    expect(r.avaliarRetorno(), isFalse);

    // registra uma queda
    r.avaliarQueda(0);
    expect(r.avaliarQueda(2 * min), isTrue);
    // retorno dispara e reseta
    expect(r.avaliarRetorno(), isTrue);
    // apos reset, um novo ciclo de queda conta do zero
    expect(r.avaliarQueda(2 * min), isFalse);
    expect(r.avaliarQueda(4 * min), isTrue);
  });
}
