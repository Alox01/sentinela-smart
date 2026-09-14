import 'package:estufa_app/features/relatorio_estufada/eventos_de_ajuste.dart';
import 'package:estufa_app/features/relatorio_estufada/eventos_de_alarme.dart';
import 'package:estufa_app/features/relatorio_estufada/leitura_valida.dart';
import 'package:estufa_app/models/historico_leitura_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// A leitura zerada que o app gravava ao encerrar a estufada antes de ter
/// leitura de verdade (estufada #22, 14/09/2026 14:09).
void main() {
  HistoricoLeituraEntity leitura(
    int minuto, {
    double temperatura = 59,
    double umidade = 73,
    double ajusteTemp = 70,
    double ajusteUmid = 65,
    bool alarme = true,
    String aviso = 'Temperatura baixa',
  }) {
    return HistoricoLeituraEntity()
      ..ipEstufa = 'sentinela-215788.local'
      ..nomeEstufa = 'Estufa 1'
      ..timestamp = DateTime(2026, 9, 14, 14).add(Duration(minutes: minuto))
      ..temperatura = temperatura
      ..umidade = umidade
      ..temperaturaMeta = ajusteTemp
      ..umidadeMeta = ajusteUmid
      ..aviso = aviso
      ..alertaIncendio = alarme;
  }

  final zerada = leitura(
    9,
    temperatura: 0,
    umidade: 0,
    ajusteTemp: 0,
    ajusteUmid: 0,
    alarme: false,
    aviso: '',
  );

  test('a leitura zerada nao e leitura', () {
    expect(leituraValida(zerada), isFalse);
    expect(leituraValida(leitura(2)), isTrue);
    // Umidade 0% com o resto de verdade continua valendo.
    expect(leituraValida(leitura(3, umidade: 0)), isTrue);
  });

  test('sem ela, o fim da #22 nao inventa ajuste 0 nem alarme normalizado', () {
    final leituras = [leitura(0, alarme: false, aviso: 'Estável'), leitura(2), zerada];

    final comZerada = [
      ...eventosDeAjuste(leituras),
      ...eventosDeAlarme(leituras),
    ].map((e) => e.descricao);
    expect(comZerada, contains('Ajuste de temperatura alterado de 70 para 0°F.'));

    final validas = leituras.where(leituraValida).toList();
    final semZerada = [
      ...eventosDeAjuste(validas),
      ...eventosDeAlarme(validas),
    ].map((e) => e.descricao).toList();
    expect(semZerada, ['Alarme acionado: Temperatura baixa.']);
  });
}
