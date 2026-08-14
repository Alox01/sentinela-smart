import 'package:estufa_app/features/relatorio_estufada/duracao_estufada.dart';
import 'package:flutter_test/flutter_test.dart';

/// A duração vinha do intervalo entre a primeira e a última leitura mostrada.
///
/// Apareceu em campo filtrando um dia e lendo "10:00 h" — havia só 10h de
/// leitura naquele dia, porque o aparelho passou o resto desligado. O defeito
/// maior estava escondido atrás desse: mesmo SEM filtro, faltar leitura na ponta
/// encurtava a estufada, e nada na tela dizia que aquilo tinha acontecido.
void main() {
  final comeco = DateTime(2026, 8, 10, 6);

  test('a estufada encerrada dura do início ao fim do ciclo', () {
    final duracao = duracaoDaEstufada(
      inicioDoCiclo: comeco,
      fimDoCiclo: comeco.add(const Duration(hours: 96)),
      // Leituras cobrindo só um pedaço: aparelho desligado no resto.
      intervaloDasLeituras: const Duration(hours: 10),
    );

    expect(duracao, const Duration(hours: 96));
  });

  test('filtrar não encurta a estufada', () {
    // O caso da queixa: um dia filtrado, 10h de leitura dentro dele. Filtrar
    // muda o que se olha, não quanto tempo a secagem durou.
    final duracao = duracaoDaEstufada(
      inicioDoCiclo: comeco,
      fimDoCiclo: comeco.add(const Duration(hours: 96)),
      intervaloDasLeituras: const Duration(hours: 10),
    );

    expect(duracao.inHours, 96);
  });

  test('estufada em andamento corre até agora', () {
    final duracao = duracaoDaEstufada(
      inicioDoCiclo: comeco,
      fimDoCiclo: null,
      intervaloDasLeituras: const Duration(hours: 2),
      agora: comeco.add(const Duration(hours: 30)),
    );

    expect(duracao, const Duration(hours: 30));
  });

  test('sem ciclo, as leituras são a única medida que existe', () {
    // Histórico antigo, gravado antes de existir ciclo.
    final duracao = duracaoDaEstufada(
      inicioDoCiclo: null,
      fimDoCiclo: null,
      intervaloDasLeituras: const Duration(hours: 7, minutes: 30),
    );

    expect(duracao, const Duration(hours: 7, minutes: 30));
  });

  test('fim antes do início não vira duração negativa', () {
    // Relógio do aparelho e do celular podem discordar. "-03:00 h" na tela
    // seria pior do que zero.
    final duracao = duracaoDaEstufada(
      inicioDoCiclo: comeco,
      fimDoCiclo: comeco.subtract(const Duration(hours: 3)),
      intervaloDasLeituras: const Duration(hours: 1),
    );

    expect(duracao, Duration.zero);
  });
}
