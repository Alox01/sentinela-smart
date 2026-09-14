import 'package:estufa_app/features/relatorio_estufada/eventos_de_ajuste.dart';
import 'package:estufa_app/models/historico_leitura_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// D7: o evento de "ajuste alterado" sai das leituras, e nao do comando do app.
void main() {
  final inicio = DateTime(2026, 9, 13, 13);

  HistoricoLeituraEntity leitura(
    int minuto, {
    double ajusteTemp = 68,
    double ajusteUmid = 70,
    bool semAjuste = false,
  }) {
    return HistoricoLeituraEntity()
      ..ipEstufa = 'sentinela-215788.local'
      ..nomeEstufa = 'Estufa 1'
      ..timestamp = inicio.add(Duration(minutes: minuto))
      ..temperatura = semAjuste ? 60 + minuto.toDouble() : 64
      ..umidade = 70
      ..temperaturaMeta = semAjuste ? 60 + minuto.toDouble() : ajusteTemp
      ..umidadeMeta = ajusteUmid
      ..aviso = ''
      ..alertaIncendio = false;
  }

  List<String> descricoes(List<HistoricoLeituraEntity> leituras) =>
      eventosDeAjuste(leituras).map((e) => e.descricao).toList();

  test('mudanca feita no aparelho vira evento, mesmo sem o app mandar nada', () {
    // O caso de 13/09 13:11: o ajuste foi de 68 para 70 nos botoes, e o
    // relatorio nao tinha linha nenhuma.
    final leituras = [
      leitura(0),
      leitura(10),
      leitura(11, ajusteTemp: 70),
      leitura(21, ajusteTemp: 70),
    ];

    final eventos = eventosDeAjuste(leituras);
    expect(eventos, hasLength(1));
    expect(eventos.single.descricao, 'Ajuste de temperatura alterado de 68 para 70°F.');
    expect(eventos.single.timestamp, inicio.add(const Duration(minutes: 11)));
    expect(eventos.single.valorAnterior, 68);
    expect(eventos.single.valorAtual, 70);
  });

  test('a rajada de ajustes vira uma linha so, de onde saiu para onde parou', () {
    // 14:12 no relatorio de 13/09: 75, 76, 80, 85, 80, 70 em dois minutos.
    final leituras = [
      leitura(0, ajusteTemp: 70),
      leitura(1, ajusteTemp: 75),
      leitura(2, ajusteTemp: 80),
      leitura(3, ajusteTemp: 85),
      leitura(4, ajusteTemp: 80),
      leitura(20, ajusteTemp: 80),
    ];

    expect(descricoes(leituras), [
      'Ajuste de temperatura alterado de 70 para 80°F.',
    ]);
  });

  test('ir e voltar ao mesmo valor nao e mudanca', () {
    final leituras = [
      leitura(0, ajusteTemp: 70),
      leitura(1, ajusteTemp: 85),
      leitura(2, ajusteTemp: 70),
      leitura(20, ajusteTemp: 70),
    ];

    expect(eventosDeAjuste(leituras), isEmpty);
  });

  test('mudancas separadas por mais de 5 min sao duas linhas', () {
    final leituras = [
      leitura(0, ajusteTemp: 70),
      leitura(1, ajusteTemp: 75),
      leitura(30, ajusteTemp: 75),
      leitura(31, ajusteTemp: 69),
    ];

    expect(descricoes(leituras), [
      'Ajuste de temperatura alterado de 70 para 75°F.',
      'Ajuste de temperatura alterado de 75 para 69°F.',
    ]);
  });

  test('umidade tambem, com a unidade dela, em ordem de horario', () {
    final leituras = [
      leitura(0, ajusteTemp: 70, ajusteUmid: 70),
      leitura(10, ajusteTemp: 75, ajusteUmid: 70),
      leitura(20, ajusteTemp: 75, ajusteUmid: 60),
    ];

    expect(descricoes(leituras), [
      'Ajuste de temperatura alterado de 70 para 75°F.',
      'Ajuste de umidade alterado de 70 para 60%.',
    ]);
  });

  test('leitura sem ajuste nao inventa mudanca', () {
    // Leitura antiga da nuvem: sem o ajuste, ele vem igual a propria leitura, e
    // cada ponto pareceria uma mudanca.
    final leituras = [
      leitura(0),
      leitura(10, semAjuste: true),
      leitura(20, semAjuste: true),
      leitura(30),
    ];
    final semAjuste = {leituras[1], leituras[2]};

    expect(
      eventosDeAjuste(leituras, temAjuste: (l) => !semAjuste.contains(l)),
      isEmpty,
    );
  });

  test('fora de ordem sai certo', () {
    final leituras = [
      leitura(20, ajusteTemp: 72),
      leitura(0),
      leitura(10, ajusteTemp: 72),
    ];

    expect(descricoes(leituras), [
      'Ajuste de temperatura alterado de 68 para 72°F.',
    ]);
  });
}
