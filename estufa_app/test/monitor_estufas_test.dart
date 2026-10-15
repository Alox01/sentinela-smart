import 'dart:async';

import 'package:estufa_app/services/api_service.dart';
import 'package:estufa_app/services/monitor_estufas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Busca controlada pelo teste: nenhuma rede envolvida.
class BuscaFalsa {
  int chamadas = 0;
  Completer<Map<String, dynamic>?>? emAndamento;
  Map<String, dynamic>? resposta = {
    'status': {'temperaturaAtual': 90},
  };

  Future<Map<String, dynamic>?> buscar() {
    chamadas++;
    final completer = Completer<Map<String, dynamic>?>();
    emAndamento = completer;
    return completer.future;
  }

  void responder([Map<String, dynamic>? dados]) {
    emAndamento?.complete(dados ?? resposta);
    emAndamento = null;
  }

  /// Busca que nao alcancou nem o aparelho nem a nuvem.
  void responderFalha() {
    emAndamento?.complete(null);
    emAndamento = null;
  }
}

EstufaMonitor criarMonitor(
  BuscaFalsa busca, {
  // Intervalo longo de proposito: os testes disparam as buscas na mao, para a
  // contagem de chamadas nao depender de quando o timer resolve bater.
  Duration intervalo = const Duration(minutes: 5),
  ApiService? api,
}) {
  return EstufaMonitor(
    api: api ?? ApiService('192.168.0.10'),
    buscar: busca.buscar,
    intervalo: intervalo,
  );
}

/// Um `ApiService` que ja resolveu a conexao local, para o selo publicado pelo
/// monitor ser LOCAL e nao o OFFLINE de quem nunca falou com ninguem.
Future<ApiService> apiEmLocal() async {
  final api = ApiService(
    '192.168.0.10',
    idHardware: 'ESP32_ABC',
    cliente: MockClient(
      (_) async => http.Response(
        '{"status":{"idHardware":"ESP32_ABC"}}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
  await api.resolverConexao();
  return api;
}

void main() {
  test('so busca quando alguem esta assinando', () async {
    final busca = BuscaFalsa();
    final monitor = criarMonitor(busca);

    expect(monitor.ativo, isFalse);
    expect(busca.chamadas, 0);

    void ouvinte() {}
    monitor.assinar(ouvinte);

    // O primeiro assinante dispara uma busca imediata: quem abre a tela nao
    // deve esperar o primeiro tique do timer.
    expect(busca.chamadas, 1);
    expect(monitor.ativo, isTrue);

    monitor.desassinar(ouvinte);
    expect(monitor.ativo, isFalse);

    monitor.dispose();
  });

  test('o segundo assinante nao dispara outra busca', () async {
    final busca = BuscaFalsa();
    final monitor = criarMonitor(busca);

    void primeiro() {}
    void segundo() {}
    monitor.assinar(primeiro);
    monitor.assinar(segundo);

    expect(busca.chamadas, 1);

    // Continua ativo enquanto sobrar alguem: sair da tela de monitoramento nao
    // pode desligar a leitura dos cards.
    monitor.desassinar(primeiro);
    expect(monitor.ativo, isTrue);

    monitor.desassinar(segundo);
    expect(monitor.ativo, isFalse);

    monitor.dispose();
  });

  test('nao sobrepoe buscas enquanto uma esta em andamento', () async {
    final busca = BuscaFalsa();
    final monitor = criarMonitor(busca);

    void ouvinte() {}
    monitor.assinar(ouvinte);
    expect(busca.chamadas, 1);

    // Uma leitura lenta: as tentativas seguintes precisam ser descartadas, e
    // nao enfileiradas em cima dela.
    unawaited(monitor.atualizarAgora());
    unawaited(monitor.atualizarAgora());
    expect(busca.chamadas, 1);

    busca.responder();
    await Future<void>.delayed(Duration.zero);

    // Com a anterior concluida, a proxima passa.
    unawaited(monitor.atualizarAgora());
    expect(busca.chamadas, 2);
    busca.responder();
    await Future<void>.delayed(Duration.zero);

    monitor.desassinar(ouvinte);
    monitor.dispose();
  });

  test('guarda a ultima leitura para quem assinar depois', () async {
    final busca = BuscaFalsa();
    final monitor = criarMonitor(busca);

    expect(monitor.ultima, isNull);

    void primeiro() {}
    monitor.assinar(primeiro);
    busca.responder({
      'status': {'temperaturaAtual': 95},
    });
    await Future<void>.delayed(Duration.zero);

    final leitura = monitor.ultima;
    expect(leitura, isNotNull);
    expect(leitura!.temDados, isTrue);
    expect(leitura.dados!['status']['temperaturaAtual'], 95);

    // O ganho todo: quem chega depois ja encontra o valor, sem esperar rede.
    void segundo() {}
    monitor.assinar(segundo);
    expect(monitor.ultima, same(leitura));

    monitor.desassinar(primeiro);
    monitor.desassinar(segundo);
    monitor.dispose();
  });

  test(
    'busca falha vira leitura sem dados, nao fica no valor antigo',
    () async {
      final busca = BuscaFalsa();
      final monitor = criarMonitor(busca);

      void ouvinte() {}
      monitor.assinar(ouvinte);
      busca.responder({
        'status': {'temperaturaAtual': 95},
      });
      await Future<void>.delayed(Duration.zero);
      expect(monitor.ultima!.temDados, isTrue);

      unawaited(monitor.atualizarAgora());
      busca.responderFalha();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.ultima!.temDados, isFalse);

      monitor.desassinar(ouvinte);
      monitor.dispose();
    },
  );

  test(
    'cada leitura tem um instante proprio, para nao repetir efeitos',
    () async {
      final busca = BuscaFalsa();
      final monitor = criarMonitor(busca);

      void ouvinte() {}
      monitor.assinar(ouvinte);
      busca.responder();
      await Future<void>.delayed(Duration.zero);
      final primeira = monitor.ultima!.recebidaEmMs;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      unawaited(monitor.atualizarAgora());
      busca.responder();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.ultima!.recebidaEmMs, greaterThanOrEqualTo(primeira));

      monitor.desassinar(ouvinte);
      monitor.dispose();
    },
  );

  test('pausar interrompe e retomar so religa se houver assinante', () async {
    final busca = BuscaFalsa();
    final monitor = criarMonitor(busca);

    void ouvinte() {}
    monitor.assinar(ouvinte);
    expect(monitor.ativo, isTrue);

    monitor.pausar();
    expect(monitor.ativo, isFalse);

    monitor.retomar();
    expect(monitor.ativo, isTrue);

    monitor.desassinar(ouvinte);
    monitor.pausar();
    monitor.retomar();
    // Sem ninguem olhando, voltar do segundo plano nao deve religar nada.
    expect(monitor.ativo, isFalse);

    monitor.dispose();
  });

  group('o selo de conexao nao pisca', () {
    // Relatado em campo em 15/10/2026: "fica alternando a cada x segundos entre
    // offline, nuvem e local". Com a tela lendo a cada 3 s, cada leitura perdida
    // - um pacote que se perdeu, o nome mDNS demorando, o Wi-Fi do celular
    // trocando de canal - virava um piscar no selo.

    test('uma leitura perdida segura o selo anterior', () async {
      final busca = BuscaFalsa();
      final monitor = criarMonitor(busca, api: await apiEmLocal());
      void ouvinte() {}
      monitor.assinar(ouvinte);

      busca.responder();
      await Future<void>.delayed(Duration.zero);
      expect(monitor.ultima!.modoConexao, 'LOCAL');

      unawaited(monitor.atualizarAgora());
      busca.responderFalha();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.ultima!.temDados, isFalse);
      expect(
        monitor.ultima!.modoConexao,
        'LOCAL',
        reason: 'uma leitura perdida nao e queda',
      );

      monitor.desassinar(ouvinte);
      monitor.dispose();
    });

    test('duas seguidas ja sao OFFLINE', () async {
      final busca = BuscaFalsa();
      final monitor = criarMonitor(busca, api: await apiEmLocal());
      void ouvinte() {}
      monitor.assinar(ouvinte);

      busca.responder();
      await Future<void>.delayed(Duration.zero);

      for (var i = 0; i < 2; i++) {
        unawaited(monitor.atualizarAgora());
        busca.responderFalha();
        await Future<void>.delayed(Duration.zero);
      }

      expect(monitor.ultima!.modoConexao, 'OFFLINE');

      monitor.desassinar(ouvinte);
      monitor.dispose();
    });

    test('a leitura que volta zera a contagem', () async {
      final busca = BuscaFalsa();
      final monitor = criarMonitor(busca, api: await apiEmLocal());
      void ouvinte() {}
      monitor.assinar(ouvinte);

      busca.responder();
      await Future<void>.delayed(Duration.zero);

      unawaited(monitor.atualizarAgora());
      busca.responderFalha();
      await Future<void>.delayed(Duration.zero);

      unawaited(monitor.atualizarAgora());
      busca.responder();
      await Future<void>.delayed(Duration.zero);

      // Esta e a terceira falha da sessao. Se a contagem nao tivesse zerado na
      // leitura que voltou, ela ja estaria dizendo OFFLINE.
      unawaited(monitor.atualizarAgora());
      busca.responderFalha();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.ultima!.modoConexao, 'LOCAL');

      monitor.desassinar(ouvinte);
      monitor.dispose();
    });
  });
}
