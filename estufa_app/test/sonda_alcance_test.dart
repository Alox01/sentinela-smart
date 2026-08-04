import 'dart:convert';

import 'package:estufa_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// O teste de alcance da tela "Detalhes da conexão".
///
/// ## O defeito que motivou este arquivo
///
/// A sonda pedia `/status` pelado, enquanto toda leitura de verdade manda
/// `?idHardware=...`. São requisições diferentes para o servidor: sem o id ele
/// não sabe de qual aparelho se fala, e a isenção do simulador — que é **por
/// id** — não vale. O resultado era a tela se contradizendo, com o cartão
/// dizendo "Reportando (via nuvem)", números na tela, e o teste de alcance logo
/// abaixo dizendo "Nuvem: offline".
///
/// Nenhum teste podia ter pego isso: o `ApiService` chamava `http.get` direto,
/// sem costura para interceptar. Ele agora recebe um `http.Client`, e é essa
/// costura que estes testes usam.
void main() {
  const corpoStatus = '{"status":{"idHardware":"ESP32_ABC","temperaturaAtual":130}}';

  /// Guarda toda URL pedida, e responde o que o teste mandar.
  ({MockClient cliente, List<Uri> pedidas}) espiao({
    int Function(Uri url)? statusPara,
  }) {
    final pedidas = <Uri>[];
    final cliente = MockClient((requisicao) async {
      pedidas.add(requisicao.url);
      final codigo = statusPara?.call(requisicao.url) ?? 200;
      return http.Response(
        codigo == 200 ? corpoStatus : '{"erro":"nao autorizado"}',
        codigo,
        headers: {'content-type': 'application/json'},
      );
    });
    return (cliente: cliente, pedidas: pedidas);
  }

  test('a sonda leva o idHardware, como a leitura de verdade', () async {
    final espia = espiao();
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: espia.cliente,
    );

    await api.verificarConexoes(forcar: true);

    final nuvem = espia.pedidas.where((u) => u.host == 'nuvem.exemplo');
    expect(nuvem, isNotEmpty, reason: 'a nuvem nem foi sondada');
    expect(
      nuvem.every((u) => u.queryParameters['idHardware'] == 'ESP32_ABC'),
      isTrue,
      reason: 'sem o id o servidor não sabe de qual aparelho se fala — e a '
          'isenção do simulador, que é por id, deixa de valer',
    );
  });

  test('sem idHardware conhecido, pede /status pelado', () async {
    // Estufa que ainda não se apresentou. Mandar `idHardware=` vazio seria pior
    // do que não mandar: o servidor trataria como um id que não existe.
    final espia = espiao();
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      cliente: espia.cliente,
    );

    await api.verificarConexoes(forcar: true);

    expect(
      espia.pedidas.every((u) => !u.queryParameters.containsKey('idHardware')),
      isTrue,
    );
  });

  test('nuvem que responde 200 aparece como online', () async {
    final espia = espiao();
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: espia.cliente,
    );

    final probes = await api.verificarConexoes(forcar: true);
    final nuvem = probes.firstWhere((p) => p.nome == 'Nuvem');

    expect(nuvem.online, isTrue);
  });

  test('nuvem que recusa a credencial aparece como offline', () async {
    // O estado que o produtor via de verdade: 401 em toda tentativa. Aqui ele é
    // honesto — a sonda mandou o que devia e o servidor recusou.
    final espia = espiao(statusPara: (_) => 401);
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave-errada',
      idHardware: 'ESP32_ABC',
      cliente: espia.cliente,
    );

    final probes = await api.verificarConexoes(forcar: true);
    final nuvem = probes.firstWhere((p) => p.nome == 'Nuvem');

    expect(nuvem.online, isFalse);
  });

  test('as duas portas locais viram uma linha só', () async {
    // O aparelho é o mesmo em 3000 (servidor) e 80 (ESP32). Duas linhas
    // "Local" fariam o produtor procurar dois aparelhos onde há um.
    final espia = espiao();
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: espia.cliente,
    );

    final probes = await api.verificarConexoes(forcar: true);

    expect(probes.where((p) => p.nome == 'Local').length, 1);
  });

  test('o resultado fica guardado, e `forcar` refaz', () async {
    // Reabrir o diálogo mostra o que já se sabe em vez de sondar tudo de novo —
    // cada sondagem é uma ida à rede, e a nuvem no plano gratuito demora.
    final espia = espiao();
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: espia.cliente,
    );

    await api.verificarConexoes(forcar: true);
    final depoisDaPrimeira = espia.pedidas.length;

    await api.verificarConexoes();
    expect(espia.pedidas.length, depoisDaPrimeira, reason: 'sondou de novo');

    await api.verificarConexoes(forcar: true);
    expect(espia.pedidas.length, greaterThan(depoisDaPrimeira));
  });

  test('a sonda manda a chave de acesso no cabeçalho', () async {
    // Sem ela o servidor recusa, e a sonda diria offline para uma nuvem sã.
    final chaves = <String, String>{};
    final cliente = MockClient((requisicao) async {
      chaves.addAll(requisicao.headers);
      return http.Response(corpoStatus, 200);
    });
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave-do-aparelho',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );

    await api.verificarConexoes(forcar: true);

    expect(chaves['X-Device-Token'], 'chave-do-aparelho');
    expect(chaves['Authorization'], 'Bearer chave-do-aparelho');
  });

  test('corpo que não é do Sentinela não conta como online', () async {
    // Endereço reaproveitado por outro aparelho da rede: responder 200 não
    // basta, senão a estufa "responde" por um roteador ou uma câmera.
    final cliente = MockClient((_) async => http.Response('ola mundo', 200));
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );

    final probes = await api.verificarConexoes(forcar: true);

    expect(probes.every((p) => !p.online), isTrue);
  });

  test('JSON qualquer na raiz ainda conta: é o protótipo antigo', () async {
    // Alguns ESP32 antigos respondem o JSON direto em `/`. A sonda tenta a raiz
    // depois de `/status`, e aceitar isso é de propósito.
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.contains('status')) {
        return http.Response('nao existe', 404);
      }
      return http.Response(jsonEncode({'temperatura': 130}), 200);
    });
    final api = ApiService(
      '192.168.0.50',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );

    final probes = await api.verificarConexoes(forcar: true);

    expect(probes.firstWhere((p) => p.nome == 'Local').online, isTrue);
  });
}
