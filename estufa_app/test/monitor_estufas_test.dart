import 'dart:async';

import 'package:estufa_app/services/api_service.dart';
import 'package:estufa_app/services/monitor_estufas.dart';
import 'package:flutter_test/flutter_test.dart';

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
}) {
  return EstufaMonitor(
    api: ApiService('192.168.0.10'),
    buscar: busca.buscar,
    intervalo: intervalo,
  );
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

  test('busca falha vira leitura sem dados, nao fica no valor antigo', () async {
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
  });

  test('cada leitura tem um instante proprio, para nao repetir efeitos', () async {
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
  });

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
}
