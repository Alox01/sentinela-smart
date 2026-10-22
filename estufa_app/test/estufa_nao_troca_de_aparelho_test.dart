import 'package:estufa_app/features/home/services/atualizacao_estufa.dart';
import 'package:flutter_test/flutter_test.dart';

/// D17 — uma estufa cadastrada nao pode trocar de aparelho sozinha.
///
/// ## O caso, como aconteceu
///
/// 19/10/2026. O aparelho de um parente foi ligado na rede do produtor para
/// ser configurado, enquanto o aparelho do produtor estava **desligado**. O
/// roteador entregou ao ESP32 novo o endereco que era do antigo — concessao
/// vencida, endereco de volta ao bolo.
///
/// A partir dali o app, ao falar com aquele endereco, recebeu outro
/// `idHardware`. E `AtualizacaoDeEstufa.entre()` fazia:
///
/// ```dart
/// idHardware: idHardwareNovo ?? idHardwareAtual,
/// ```
///
/// O recebido vencia o cadastrado. A estufa do produtor passou a apontar para
/// o aparelho do parente, carregando a chave de acesso do antigo — que o novo
/// recusa. Sintoma final: comandos falhando por credencial, numa estufa que
/// continuava com o nome certo na lista.
///
/// ## O que este arquivo afirma
///
/// 1. aparelho cadastrado **vence** o que respondeu no endereco;
/// 2. estufa **sem** aparelho ainda aprende o dele — era para isso que a linha
///    existia, e isso nao pode se perder no conserto;
/// 3. quando os dois diferem, a atualizacao **avisa**, em vez de trocar calada.
void main() {
  group('D17 - identidade da estufa e o aparelho, nao o endereco', () {
    test('o aparelho cadastrado vence o que atendeu no endereco', () {
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 1,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-do-produtor',
        idHardwareAtual: 'ESP32_AAAAAA',
        enderecoNovo: '192.168.0.51',
        chaveNova: null,
        idHardwareNovo: 'ESP32_BBBBBB',
      );

      expect(mudanca, isNotNull);
      expect(
        mudanca!.idHardware,
        'ESP32_AAAAAA',
        reason: 'o aparelho do parente nao pode herdar a estufa do produtor',
      );
    });

    test('a estufa sem aparelho ainda aprende o dele', () {
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 2,
        nome: 'Estufa Nova',
        enderecoAtual: '192.168.0.60',
        chaveAtual: null,
        idHardwareAtual: null,
        enderecoNovo: '192.168.0.61',
        chaveNova: null,
        idHardwareNovo: 'ESP32_CCCCCC',
      );

      expect(mudanca, isNotNull);
      expect(mudanca!.idHardware, 'ESP32_CCCCCC');
    });

    test('aparelho diferente no endereco vira aviso, nao troca silenciosa', () {
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 3,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-do-produtor',
        idHardwareAtual: 'ESP32_AAAAAA',
        enderecoNovo: '192.168.0.51',
        chaveNova: null,
        idHardwareNovo: 'ESP32_BBBBBB',
      );

      expect(mudanca!.aparelhoDiferente, isTrue);
      expect(mudanca.avisoDeAparelho, isNotNull);
      expect(mudanca.avisoDeAparelho, contains('aparelho diferente'));
    });

    test('mesmo aparelho em endereco novo nao gera aviso nenhum', () {
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 4,
        nome: 'Estufa do Fundo',
        enderecoAtual: '192.168.0.50',
        chaveAtual: 'chave-do-produtor',
        idHardwareAtual: 'ESP32_AAAAAA',
        enderecoNovo: '192.168.0.77',
        chaveNova: null,
        idHardwareNovo: 'ESP32_AAAAAA',
      );

      expect(mudanca!.aparelhoDiferente, isFalse);
      expect(mudanca.avisoDeAparelho, isNull);
      expect(
        mudanca.idHardware,
        'ESP32_AAAAAA',
        reason: 'trocar de endereco e normal: o DHCP faz isso sozinho',
      );
    });

    test('id legado evolui para o MAC completo sem virar outro aparelho', () {
      final mudanca = AtualizacaoDeEstufa.entre(
        id: 5,
        nome: 'Estufa do Fundo',
        enderecoAtual: 'sentinela-215788.local',
        chaveAtual: 'chave-do-produtor',
        idHardwareAtual: 'ESP32_215788',
        enderecoNovo: 'sentinela-aabbcc215788.local',
        chaveNova: 'chave-do-produtor',
        idHardwareNovo: 'ESP32_AABBCC215788',
      );

      expect(mudanca, isNotNull);
      expect(mudanca!.idHardware, 'ESP32_AABBCC215788');
      expect(mudanca.mudaIdentidade, isTrue);
      expect(mudanca.aparelhoDiferente, isFalse);
    });
  });
}
