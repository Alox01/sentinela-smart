import 'package:estufa_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Como o app escolhe entre falar com o aparelho na rede local e falar com a
/// nuvem.
///
/// ## Os dois defeitos que motivaram este arquivo
///
/// Relatados em campo em 15/10/2026, na mesma frase: *"a estufa real demora
/// bastante pra se conectar até mesmo no modo local, e às vezes do nada muda
/// pra nuvem mesmo o local funcionando"*.
///
/// 1. **A escolha esperava a sonda mais lenta.** As candidatas locais eram
///    sondadas em paralelo, mas com `Future.wait` — que só volta quando a
///    ÚLTIMA termina. O nome mDNS é a primeira candidata e leva até 4 s para
///    desistir no Android; o IP aprendido responde numa fração de segundo e
///    ficava esperando o nome. A estufa de demonstração não sofria disso porque
///    o nome dela não existe em rede nenhuma e falha na hora, em vez de pendurar.
///
/// 2. **Uma queda isolada para a nuvem contaminava as outras telas.** A
///    resolução escolhida era guardada num cache estático compartilhado, a
///    nuvem inclusive, e o construtor adota o que estiver lá sem sondar. Uma
///    falha isolada do nome mDNS — que acontece sozinha — levava qualquer tela
///    aberta nos 30 s seguintes direto para a nuvem, com a rede local
///    funcionando do lado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const corpo = '{"status":{"idHardware":"ESP32_ABC","temperaturaAtual":130}}';

  http.Response ok() =>
      http.Response(corpo, 200, headers: {'content-type': 'application/json'});

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nao espera a sonda lenta quando outra local ja respondeu', () async {
    // O IP aprendido em outra sessão. É ele que responde rápido, e é ele que o
    // app precisa usar sem esperar o nome mDNS desistir.
    SharedPreferences.setMockInitialValues({
      'ip_reportado_ESP32_ABC': '192.168.0.77',
    });

    final cliente = MockClient((requisicao) async {
      if (requisicao.url.host.endsWith('.local')) {
        // Nome que não resolve não devolve erro: fica pendurado até o prazo.
        await Future<void>.delayed(const Duration(seconds: 4));
        throw http.ClientException('sem resolucao');
      }
      if (requisicao.url.port != 80) {
        throw http.ClientException('o ESP32 so escuta na porta 80');
      }
      return ok();
    });

    final api = ApiService(
      'sentinela-abc123',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );

    final cronometro = Stopwatch()..start();
    final base = await api.resolverConexao();
    cronometro.stop();

    expect(base, 'http://192.168.0.77:80');
    expect(api.modoConexao, 'LOCAL');
    expect(
      cronometro.elapsed,
      lessThan(const Duration(seconds: 2)),
      reason:
          'esperou o nome mDNS desistir em vez de sair com o IP que já '
          'tinha respondido',
    );
  });

  test('IP aprendido do ESP usa porta 80 e preserva porta explicita', () async {
    SharedPreferences.setMockInitialValues({
      'ip_reportado_ESP32_DEF456': '192.168.0.78:8080',
    });

    final portas = <int>[];
    final cliente = MockClient((requisicao) async {
      portas.add(requisicao.url.port);
      if (requisicao.url.host.endsWith('.local')) {
        throw http.ClientException('mDNS indisponivel');
      }
      if (requisicao.url.port == 8080) {
        return http.Response(
          '{"status":{"idHardware":"ESP32_DEF456"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      throw http.ClientException('porta errada');
    });

    final api = ApiService(
      'sentinela-def456.local',
      idHardware: 'ESP32_DEF456',
      cliente: cliente,
    );

    expect(await api.resolverConexao(), 'http://192.168.0.78:8080');
    expect(portas, contains(8080));
    expect(api.modoConexao, 'LOCAL');
  });

  test('queda para a nuvem nao e herdada pela proxima tela', () async {
    // Nada local responde: esta instância cai para a nuvem, como deve.
    final clienteSemLocal = MockClient((requisicao) async {
      if (requisicao.url.host == 'nuvem.exemplo') return ok();
      throw http.ClientException('fora de alcance');
    });

    final primeira = ApiService(
      '192.168.0.90',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: clienteSemLocal,
    );
    await primeira.resolverConexao();
    expect(primeira.modoConexao, 'NUVEM');

    // Outra tela, aberta em seguida, com o aparelho de volta no alcance. Ela não
    // pode NASCER na nuvem por causa da queda da anterior.
    final clienteComLocal = MockClient((_) async => ok());
    final segunda = ApiService(
      '192.168.0.90',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: clienteComLocal,
    );
    expect(
      segunda.modoConexao,
      isNot('NUVEM'),
      reason: 'nasceu na nuvem herdando a queda da instância anterior',
    );

    await segunda.resolverConexao();
    expect(segunda.modoConexao, 'LOCAL');
  });

  test('lembranca de conexao local continua sendo aproveitada', () async {
    // O cache compartilhado não foi desligado: ele só deixou de guardar nuvem.
    final cliente = MockClient((_) async => ok());
    final primeira = ApiService(
      '192.168.0.91',
      cloudUrl: 'https://nuvem.exemplo',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );
    await primeira.resolverConexao();
    expect(primeira.modoConexao, 'LOCAL');

    // A segunda nasce já em LOCAL, antes de sondar qualquer coisa.
    final segunda = ApiService(
      '192.168.0.91',
      cloudUrl: 'https://nuvem.exemplo',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );
    expect(segunda.modoConexao, 'LOCAL');
  });

  test('sonda de endereco fora do ar nao paga o prazo duas vezes', () async {
    // Uma requisição por candidata, não duas: a rota raiz só é tentada quando a
    // primeira RESPONDEU algo que não parece um Sentinela. Endereço com porta
    // explícita para haver uma única candidata local.
    var pedidos = 0;
    final cliente = MockClient((_) async {
      pedidos++;
      throw http.ClientException('fora de alcance');
    });

    final api = ApiService(
      '192.168.0.92:3000',
      cloudUrl: '',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );
    await api.resolverConexao();

    expect(
      pedidos,
      1,
      reason:
          'tentou a rota raiz num endereço que nem respondeu, dobrando a '
          'espera',
    );
  });

  test('leitura real recente prevalece sobre falha isolada da sonda', () async {
    var getsLocais = 0;
    final cliente = MockClient((requisicao) async {
      if (requisicao.method == 'POST') {
        return http.Response('{}', 200);
      }
      if (requisicao.url.host == 'nuvem.exemplo') return ok();

      getsLocais++;
      if (getsLocais == 1) return ok();
      throw http.ClientException('falha passageira da sonda');
    });

    final api = ApiService(
      '192.168.0.93:3000',
      cloudUrl: 'https://nuvem.exemplo',
      token: 'chave',
      idHardware: 'ESP32_ABC',
      cliente: cliente,
    );

    await api.resolverConexao();
    expect(
      await api.enviarSincronizacao({
        'temperaturaAjuste': 25,
      }, enfileirarSeOffline: false),
      isTrue,
    );
    expect(api.alcanceAtual.value?.probes, hasLength(1));
    expect(api.alcanceAtual.value?.probes.single.nome, 'Local');
    expect(api.alcanceAtual.value?.probes.single.online, isTrue);

    final alcance = await api.verificarConexoes(forcar: true);
    expect(
      alcance.firstWhere((probe) => probe.nome == 'Local').online,
      isTrue,
      reason:
          'um comando local acabou de responder e prova que o caminho esta '
          'disponivel, mesmo se uma nova sonda isolada falhar',
    );
  });
}
