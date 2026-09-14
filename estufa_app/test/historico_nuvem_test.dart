import 'package:estufa_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// O historico do relatorio vem da nuvem, e so dela.
///
/// ## O defeito que motivou este arquivo
///
/// `buscarHistorico` pedia `/historico` pela conexao ATIVA. Com o celular no
/// Wi-Fi da estufa a conexao ativa e o proprio aparelho, que nao tem essa rota:
/// voltava 404, a busca devolvia lista vazia sem avisar, e o relatorio saia so
/// com o que o app gravou no celular. Em 13/09/2026 um PDF de 34 h mostrou uma
/// noite inteira sem leitura, com 6 leituras por hora guardadas na nuvem.
void main() {
  const corpoStatus = '{"status":{"idHardware":"ESP32_ABC","temperaturaAtual":130}}';
  const corpoHistorico =
      '{"leituras":[{"timestampLeitura":1757725200000,"temperaturaAtual":120,'
      '"umidadeAtual":40}],"persistencia":true}';

  test('com o aparelho alcancavel na rede local, busca na nuvem', () async {
    final pedidas = <Uri>[];
    final cliente = MockClient((requisicao) async {
      pedidas.add(requisicao.url);
      final ehNuvem = requisicao.url.host == 'nuvem.exemplo';
      if (requisicao.url.path == '/historico') {
        // O aparelho de verdade responde assim: a rota nao existe nele.
        return ehNuvem
            ? http.Response(corpoHistorico, 200)
            : http.Response('Not found', 404);
      }
      return http.Response(corpoStatus, 200);
    });
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );

    // O celular esta no Wi-Fi da estufa: o aparelho responde a sonda, e pela
    // conexao ativa o `/historico` iria para ele.
    final leituras = await api.buscarHistorico(
      inicio: DateTime.fromMillisecondsSinceEpoch(1757720000000),
      fim: DateTime.fromMillisecondsSinceEpoch(1757730000000),
    );

    expect(leituras, hasLength(1));
    final historico = pedidas.where((u) => u.path == '/historico');
    expect(historico.map((u) => u.host), everyElement('nuvem.exemplo'));
    expect(historico.first.queryParameters['idHardware'], 'ESP32_ABC');
  });

  test('sem nuvem configurada, nao pede nada', () async {
    final pedidas = <Uri>[];
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: '',
      idHardware: 'ESP32_ABC',
      cliente: MockClient((requisicao) async {
        pedidas.add(requisicao.url);
        return http.Response(corpoStatus, 200);
      }),
    );

    final leituras = await api.buscarHistorico(
      inicio: DateTime.fromMillisecondsSinceEpoch(1757720000000),
      fim: DateTime.fromMillisecondsSinceEpoch(1757730000000),
    );

    expect(leituras, isEmpty);
    expect(pedidas.where((u) => u.path == '/historico'), isEmpty);
  });
}
