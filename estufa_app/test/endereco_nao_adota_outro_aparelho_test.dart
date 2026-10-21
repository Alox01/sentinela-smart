import 'dart:convert';

import 'package:estufa_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// D18 — o endereco local so vale se quem atende for o aparelho certo.
///
/// ## O que aconteceu em campo, 20/10/2026
///
/// O aparelho do produtor estava **desligado**. O de um parente foi ligado na
/// mesma rede e o roteador lhe deu o endereco que era do antigo. A estufa do
/// produtor, cadastrada como `sentinela-215788.local`, passou a exibir os
/// numeros do aparelho do parente, com o selo **LOCAL**.
///
/// ## De onde veio
///
/// Do commit `d29d37e` (15/10), que consertou a demora para conectar na rede
/// local: a sondagem deixou de ser **em ordem** e virou **corrida em
/// paralelo**, onde ganha o primeiro que responder. Antes o nome mDNS vinha
/// primeiro e o IP era reserva; depois, com o aparelho desligado, o nome nao
/// responde nunca e o IP reaproveitado ganha sozinho.
///
/// A guarda que existia (`_capturarIdHardwareLocal`) so agia **depois** de o
/// endereco ja ter virado a conexao ativa, e so quando a estufa tinha um
/// `idHardware` gravado.
///
/// ## O que este arquivo afirma
///
/// 1. aparelho com outro id no endereco **nao** vira conexao local;
/// 2. o aparelho certo no mesmo endereco continua valendo — o conserto nao
///    pode custar a conexao de quem esta certo;
/// 3. vale mesmo **sem** `idHardware` cadastrado, porque o nome do endereco
///    (`sentinela-215788`) ja diz qual aparelho e o dono (`ESP32_215788`).
void main() {
  /// Resposta de `/status` como o firmware monta: o aparelho informa o id
  /// DELE, nunca o que foi perguntado.
  String statusDe(String idHardware) => jsonEncode({
    'status': {
      'idHardware': idHardware,
      'temperaturaAtual': 70.0,
      'umidadeAtual': 60.0,
    },
  });

  ApiService apiComResposta(
    String corpo, {
    required String endereco,
    String? idHardware,
  }) => ApiService(
    endereco,
    idHardware: idHardware,
    cliente: MockClient((_) async => http.Response(corpo, 200)),
  );

  group('D18 - o endereco nao adota outro aparelho', () {
    test('com id cadastrado, outro aparelho no endereco nao conecta', () async {
      final api = apiComResposta(
        statusDe('ESP32_BBBBBB'),
        endereco: '192.168.0.50',
        idHardware: 'ESP32_215788',
      );

      expect(await api.resolverConexao(), isNull);
      expect(api.modoConexao, 'OFFLINE');
    });

    test('SEM id cadastrado, o nome do endereco ja defende', () async {
      final api = apiComResposta(
        statusDe('ESP32_BBBBBB'),
        endereco: 'sentinela-215788.local',
      );

      expect(
        await api.resolverConexao(),
        isNull,
        reason: 'sentinela-215788 so pode ser o ESP32_215788',
      );
    });

    test('o aparelho certo continua conectando', () async {
      final api = apiComResposta(
        statusDe('ESP32_215788'),
        endereco: 'sentinela-215788.local',
        idHardware: 'ESP32_215788',
      );

      expect(await api.resolverConexao(), isNotNull);
      expect(api.modoConexao, 'LOCAL');
    });

    test('endereco sem nome de sentinela e sem id nao barra ninguem', () async {
      // Estufa digitada a mao, por IP, que nunca alcancou o aparelho: nao ha
      // com o que comparar, e barrar aqui deixaria o cadastro novo sem saida.
      final api = apiComResposta(
        statusDe('ESP32_CCCCCC'),
        endereco: '192.168.0.99',
      );

      expect(await api.resolverConexao(), isNotNull);
    });
  });
}
