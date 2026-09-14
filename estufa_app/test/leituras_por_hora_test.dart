import 'package:estufa_app/features/relatorio_estufada/leituras_por_hora.dart';
import 'package:estufa_app/models/historico_leitura_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tabela de leituras do PDF: uma por hora, sem perder a mudanca do alarme.
void main() {
  HistoricoLeituraEntity leitura(DateTime quando, {bool alarme = false}) {
    return HistoricoLeituraEntity()
      ..ipEstufa = '192.168.0.50'
      ..nomeEstufa = 'Estufa 1'
      ..timestamp = quando
      ..temperatura = 120
      ..umidade = 40
      ..temperaturaMeta = 120
      ..umidadeMeta = 40
      ..aviso = ''
      ..alertaIncendio = alarme;
  }

  // Seis por hora, como a nuvem guarda: 22:29, 22:39 ... ate 01:59.
  List<HistoricoLeituraEntity> aCada10Min(DateTime inicio, int quantas) => [
    for (var i = 0; i < quantas; i++)
      leitura(inicio.add(Duration(minutes: 10 * i))),
  ];

  test('fica a primeira de cada hora, e a ultima', () {
    final leituras = aCada10Min(DateTime(2026, 9, 12, 22, 29), 22);
    final horarios = leiturasPorHora(
      leituras,
    ).map((l) => '${l.timestamp.hour}:${l.timestamp.minute}').toList();

    expect(horarios, ['22:29', '23:9', '0:9', '1:9', '1:59']);
  });

  test('a leitura em que o alarme muda entra mesmo no meio da hora', () {
    final leituras = aCada10Min(DateTime(2026, 9, 13, 10, 0), 6);
    leituras[3].alertaIncendio = true; // 10:30 liga
    leituras[4].alertaIncendio = true;
    leituras[5].alertaIncendio = false; // 10:50 desliga

    final horarios = leiturasPorHora(
      leituras,
    ).map((l) => l.timestamp.minute).toList();

    expect(horarios, [0, 30, 50]);
  });

  test('fora de ordem sai em ordem', () {
    final leituras = aCada10Min(DateTime(2026, 9, 13, 8, 5), 13).reversed
        .toList();
    final resultado = leiturasPorHora(leituras);

    expect(resultado.first.timestamp, DateTime(2026, 9, 13, 8, 5));
    expect(resultado.last.timestamp, DateTime(2026, 9, 13, 10, 5));
  });

  test('duas leituras ou menos passam como estao', () {
    final leituras = aCada10Min(DateTime(2026, 9, 13, 8, 0), 2);
    expect(leiturasPorHora(leituras), leituras);
  });
}
