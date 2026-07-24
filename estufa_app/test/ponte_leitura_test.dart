import 'package:estufa_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A "ponte" repassa para a nuvem uma leitura obtida na rede local, para o
/// watchdog nao acusar "sem comunicacao" quando o que faltou foi a internet da
/// propriedade (o aparelho esta vivo — o app acabou de le-lo).
///
/// Aqui so as guardas sao exercitadas: todas retornam ANTES de qualquer chamada
/// de rede, entao o teste nao depende de HTTP. O caminho feliz (com o POST) e
/// verificado em campo, com o aparelho real.
void main() {
  group('ponte de leitura para a nuvem', () {
    final leitura = {
      'status': {'temperaturaAtual': 90, 'idHardware': 'abc123'},
      'config': {'temperaturaAlvo': 100},
    };

    test('nao repassa sem nuvem configurada', () async {
      final api = ApiService(
        '192.168.0.10',
        cloudUrl: '',
        idHardware: 'abc123',
      );
      expect(await api.repassarLeituraParaNuvem(leitura), isFalse);
    });

    test('nao repassa sem idHardware', () async {
      // Sem o id, o servidor nao saberia de qual aparelho e a telemetria.
      final api = ApiService(
        '192.168.0.10',
        cloudUrl: 'https://nuvem.exemplo',
      );
      expect(await api.repassarLeituraParaNuvem(leitura), isFalse);
    });

    test('nao repassa quando a conexao nao e local', () async {
      // Em modo nuvem a leitura JA veio de la: repassar seria eco.
      final api = ApiService(
        '192.168.0.10',
        cloudUrl: 'https://nuvem.exemplo',
        idHardware: 'abc123',
      );
      expect(api.modoConexao, isNot('LOCAL'));
      expect(await api.repassarLeituraParaNuvem(leitura), isFalse);
    });

    test('nao repassa payload sem status', () async {
      final api = ApiService(
        '192.168.0.10',
        cloudUrl: 'https://nuvem.exemplo',
        idHardware: 'abc123',
      );
      expect(await api.repassarLeituraParaNuvem({'config': {}}), isFalse);
    });
  });
}
