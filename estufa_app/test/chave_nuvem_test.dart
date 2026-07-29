import 'package:estufa_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// O app leva a chave da estufa para a nuvem, para ela autorizar comandos
/// daquele aparelho sem depender da chave global. Quem ancora a confianca e o
/// produtor lendo a chave no modo de configuracao, na frente do aparelho; o app
/// so transporta.
///
/// Como no teste da ponte, aqui so as guardas sao exercitadas: todas retornam
/// ANTES de qualquer chamada de rede. O caminho com o POST e coberto do lado do
/// servidor, em `estufa_server/test/chave_aparelho.test.js`, onde da para provar
/// o que importa (TOFU, rotacao, e chave de um aparelho nao abrir outro).
void main() {
  group('subir a chave da estufa para a nuvem', () {
    test('nao tenta sem nuvem configurada', () async {
      final api = ApiService(
        '192.168.0.10',
        cloudUrl: '',
        token: 'chave-do-aparelho',
        idHardware: 'ESP32_ABC123',
      );
      expect(
        await api.registrarChaveNaNuvem(),
        ResultadoChaveNuvem.semNuvem,
      );
    });

    test('nao tenta sem idHardware', () async {
      // A chave e registrada PARA um aparelho: sem o id nao ha a que amarrar.
      final api = ApiService(
        '192.168.0.10',
        cloudUrl: 'https://nuvem.exemplo',
        token: 'chave-do-aparelho',
      );
      expect(
        await api.registrarChaveNaNuvem(),
        ResultadoChaveNuvem.semIdHardware,
      );
    });

    test('nao tenta sem chave', () async {
      final api = ApiService(
        '192.168.0.10',
        cloudUrl: 'https://nuvem.exemplo',
        token: '',
        idHardware: 'ESP32_ABC123',
      );
      expect(
        await api.registrarChaveNaNuvem(),
        ResultadoChaveNuvem.semChave,
      );
    });
  });
}
