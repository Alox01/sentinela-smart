import 'package:estufa_app/features/relatorio_estufada/eventos_de_alarme.dart';
import 'package:estufa_app/models/evento_ciclo_entity.dart';
import 'package:estufa_app/models/historico_leitura_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alarme com o app fechado: a notificacao chegava e o relatorio nao contava.
void main() {
  final inicio = DateTime(2026, 9, 14, 14);

  HistoricoLeituraEntity leitura(
    int minuto, {
    bool alarme = false,
    String aviso = 'Estável',
  }) {
    return HistoricoLeituraEntity()
      ..ipEstufa = 'sentinela-215788.local'
      ..nomeEstufa = 'Estufa 1'
      ..timestamp = inicio.add(Duration(minutes: minuto))
      ..temperatura = 59
      ..umidade = 70
      ..temperaturaMeta = 70
      ..umidadeMeta = 65
      ..aviso = aviso
      ..alertaIncendio = alarme;
  }

  EventoCicloEntity guardado(int minuto, String tipo) {
    return EventoCicloEntity()
      ..ipEstufa = 'sentinela-215788.local'
      ..nomeEstufa = 'Estufa 1'
      ..cicloId = 22
      ..timestamp = inicio.add(Duration(minutes: minuto))
      ..tipo = tipo
      ..severidade = 'alerta'
      ..descricao = '';
  }

  test('alarme que a nuvem viu com o app fechado vira evento, com o fim', () {
    final leituras = [
      leitura(0),
      leitura(6, alarme: true, aviso: 'Temperatura baixa'),
      leitura(16, alarme: true, aviso: 'Temperatura baixa'),
      leitura(30),
    ];

    final eventos = eventosDeAlarme(leituras);
    expect(eventos.map((e) => e.descricao), [
      'Alarme acionado: Temperatura baixa.',
      'Alarme normalizado.',
    ]);
    expect(eventos.first.tipo, 'alarme_processo');
    expect(eventos.first.timestamp, inicio.add(const Duration(minutes: 6)));
    expect(eventos.last.timestamp, inicio.add(const Duration(minutes: 30)));
  });

  test('o que o app ja gravou nao se repete', () {
    final leituras = [
      leitura(0),
      leitura(6, alarme: true, aviso: 'Temperatura baixa'),
      leitura(30),
    ];
    final existentes = [
      guardado(5, 'alarme_processo'),
      guardado(31, 'alarme_normalizado'),
    ];

    expect(eventosDeAlarme(leituras, existentes: existentes), isEmpty);
  });

  test('fogo sai como alerta de incendio', () {
    final leituras = [
      leitura(0),
      leitura(1, alarme: true, aviso: 'Sensor de chama ativado'),
      leitura(2),
      leitura(20, alarme: true, aviso: 'Risco de incêndio'),
    ];

    final eventos = eventosDeAlarme(leituras);
    expect(
      eventos.where((e) => e.tipo == 'alerta_incendio'),
      hasLength(2),
    );
    expect(eventos.first.severidade, 'critico');
  });

  test('alarme que ja vinha de antes da janela nao inventa um comeco', () {
    final leituras = [
      leitura(0, alarme: true, aviso: 'Temperatura alta'),
      leitura(10, alarme: true, aviso: 'Temperatura alta'),
    ];

    expect(eventosDeAlarme(leituras), isEmpty);
  });
}
