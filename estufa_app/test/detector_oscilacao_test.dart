import 'package:flutter_test/flutter_test.dart';
import 'package:estufa_app/features/monitoramento/services/detector_oscilacao.dart';

void main() {
  const min = 60 * 1000; // 1 minuto em ms

  test('leitura dentro da tolerancia (<=5) nao gera evento', () {
    final d = DetectorOscilacao();
    expect(d.avaliarTemperatura(leitura: 94, ajuste: 90, nowMs: 0), isNull);
  });

  test('desvio de atencao so vira evento apos persistir 10 min', () {
    final d = DetectorOscilacao();
    // diferenca 8 (>5, atencao): primeira leitura so arma o relogio
    expect(d.avaliarTemperatura(leitura: 98, ajuste: 90, nowMs: 0), isNull);
    // ainda dentro do tempo minimo de 10 min
    expect(
      d.avaliarTemperatura(leitura: 98, ajuste: 90, nowMs: 9 * min),
      isNull,
    );
    // 10 min persistindo -> evento
    final ev = d.avaliarTemperatura(leitura: 98, ajuste: 90, nowMs: 10 * min);
    expect(ev, isNotNull);
    expect(ev!.tipo, 'oscilacao_temperatura');
    expect(ev.severidade, 'alerta');
    expect(ev.descricao, contains('acima'));
    expect(ev.valorAtual, 98);
    expect(ev.valorAnterior, 90);
  });

  test('desvio critico (>20) vira evento apos 5 min', () {
    final d = DetectorOscilacao();
    expect(d.avaliarTemperatura(leitura: 120, ajuste: 90, nowMs: 0), isNull);
    expect(
      d.avaliarTemperatura(leitura: 120, ajuste: 90, nowMs: 4 * min),
      isNull,
    );
    final ev = d.avaliarTemperatura(leitura: 120, ajuste: 90, nowMs: 5 * min);
    expect(ev, isNotNull);
    expect(ev!.severidade, 'critico');
  });

  test('acomodacao apos mudar o ajuste suprime o nivel de atencao', () {
    final d = DetectorOscilacao();
    // O ajuste andou 10: e essa mudanca que justifica perdoar um desvio de 10.
    d.registrarMudancaAjusteTemperatura(
      0,
      leitura: 90,
      ajusteAnterior: 90,
      ajusteNovo: 100,
    );
    expect(d.temperaturaEmAcomodacao(4 * min), isTrue);
    expect(d.temperaturaEmAcomodacao(6 * min), isFalse);

    // diferenca 10 (atencao) durante a acomodacao: relogio zerado, sem evento
    d.avaliarTemperatura(leitura: 100, ajuste: 90, nowMs: 0);
    expect(
      d.avaliarTemperatura(leitura: 100, ajuste: 90, nowMs: 4 * min),
      isNull,
    );
  });

  test('acomodacao nao impede o nivel critico', () {
    final d = DetectorOscilacao();
    d.registrarMudancaAjusteTemperatura(0);
    // diferenca 30 (critico) mesmo na acomodacao: dispara apos 5 min
    expect(d.avaliarTemperatura(leitura: 120, ajuste: 90, nowMs: 0), isNull);
    final ev = d.avaliarTemperatura(leitura: 120, ajuste: 90, nowMs: 5 * min);
    expect(ev, isNotNull);
    expect(ev!.severidade, 'critico');
  });

  test('voltar para a faixa normal gera evento de normalizacao', () {
    final d = DetectorOscilacao();
    d.avaliarTemperatura(leitura: 98, ajuste: 90, nowMs: 0);
    d.avaliarTemperatura(
      leitura: 98,
      ajuste: 90,
      nowMs: 10 * min,
    ); // entra em atencao
    final ev = d.avaliarTemperatura(leitura: 91, ajuste: 90, nowMs: 11 * min);
    expect(ev, isNotNull);
    expect(ev!.tipo, 'oscilacao_temperatura_normalizada');
    expect(ev.severidade, 'info');
  });

  test('reiniciar zera a maquina de estados', () {
    final d = DetectorOscilacao();
    d.avaliarTemperatura(leitura: 98, ajuste: 90, nowMs: 0);
    d.avaliarTemperatura(
      leitura: 98,
      ajuste: 90,
      nowMs: 10 * min,
    ); // em atencao
    d.reiniciar();
    // como voltou para 'normal', uma leitura normal nao gera "normalizada"
    expect(
      d.avaliarTemperatura(leitura: 90, ajuste: 90, nowMs: 11 * min),
      isNull,
    );
  });

  test('umidade usa unidade e textos proprios', () {
    final d = DetectorOscilacao();
    d.avaliarUmidade(leitura: 78, ajuste: 60, nowMs: 0); // diff 18 atencao
    final ev = d.avaliarUmidade(leitura: 78, ajuste: 60, nowMs: 10 * min);
    expect(ev, isNotNull);
    expect(ev!.tipo, 'oscilacao_umidade');
    expect(ev.descricao, contains('%'));
  });

  group('umidade nunca sai como alarme', () {
    // A regra vale no aparelho, na nuvem e no push; faltava valer no relatorio,
    // onde a umidade saia com a MESMA marca vermelha da temperatura critica, no
    // meio de linhas de "Alarme acionado". Numa estufa de secagem ficar muito
    // abaixo do ajuste de umidade e o objetivo, nao um defeito.
    test('mesmo 70 pontos fora do ajuste, e so registro', () {
      final d = DetectorOscilacao();
      d.avaliarUmidade(leitura: 25, ajuste: 95, nowMs: 0);
      final ev = d.avaliarUmidade(leitura: 25, ajuste: 95, nowMs: 10 * min);

      expect(ev, isNotNull);
      expect(ev!.severidade, 'registro');
      // Prova que nao e o caminho de "normal": a diferenca esta la, e grande.
      expect(ev.descricao, contains('70'));
    });

    test('nem quando continua fora por horas', () {
      final d = DetectorOscilacao();
      d.avaliarUmidade(leitura: 25, ajuste: 95, nowMs: 0);
      d.avaliarUmidade(leitura: 25, ajuste: 95, nowMs: 10 * min);
      final ev = d.avaliarUmidade(leitura: 25, ajuste: 95, nowMs: 300 * min);

      expect(ev?.tipo, 'oscilacao_umidade_continua');
      expect(ev?.severidade, 'registro');
    });

    test('e a temperatura continua alarmando, no mesmo detector', () {
      // O contraponto: se este teste passar a devolver 'registro', a mudanca
      // vazou para o lado que DEVE alarmar.
      final d = DetectorOscilacao();
      d.avaliarTemperatura(leitura: 100, ajuste: 130, nowMs: 0);
      final ev = d.avaliarTemperatura(leitura: 100, ajuste: 130, nowMs: 10 * min);

      expect(ev?.severidade, 'critico');
    });
  });
  test('folga cobre so a distancia que a mudanca criou', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    // Leitura 90, ajuste vai de 90 para 96: a mudanca criou 6 de distancia.
    // Abaixo do teto, para medir a proporcionalidade e nao o corte.
    d.registrarMudancaAjusteTemperatura(
      t0,
      leitura: 90,
      ajusteAnterior: 90,
      ajusteNovo: 96,
    );
    expect(d.folgaTemperatura(t0), 6);
  });

  // Regressao do caso real: ESP ligou com 127 e ajuste 70 (alarme tocando).
  // Ao mover o ajuste para 110 o alarme calava, porque a regra antiga olhava o
  // TAMANHO do movimento (40). Mas o alvo se aproximou da leitura: a estufa nao
  // tem nada a percorrer, e o desvio de 17 ja existia.
  test('aproximar o ajuste da leitura nao gera folga', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    d.registrarMudancaAjusteTemperatura(
      t0,
      leitura: 127,
      ajusteAnterior: 70,
      ajusteNovo: 110,
    );
    expect(d.folgaTemperatura(t0), 0);

    // E o desvio remanescente segue virando evento.
    d.avaliarTemperatura(leitura: 127, ajuste: 110, nowMs: t0);
    final evento = d.avaliarTemperatura(
      leitura: 127,
      ajuste: 110,
      nowMs: t0 + 11 * 60 * 1000,
    );
    expect(evento, isNotNull);
  });

  test('folga respeita o teto', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    d.registrarMudancaAjusteTemperatura(
      t0,
      leitura: 90,
      ajusteAnterior: 90,
      ajusteNovo: 140,
    );
    // Criou 50 de distancia, mas o teto corta em 8: um salto enorme de ajuste
    // nao pode cegar o alerta.
    expect(d.folgaTemperatura(t0), 8);
  });

  test('fora da janela a folga zera', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    d.registrarMudancaAjusteTemperatura(
      t0,
      leitura: 90,
      ajusteAnterior: 90,
      ajusteNovo: 100,
    );
    expect(d.folgaTemperatura(t0 + 6 * 60 * 1000), 0);
  });

  test('desvio dentro da folga segue perdoado durante a janela', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    // Saltou o alvo de 117 para 132 com a leitura em 117: criou 15 de distancia.
    d.registrarMudancaAjusteTemperatura(
      t0,
      leitura: 117,
      ajusteAnterior: 117,
      ajusteNovo: 132,
    );
    // Dentro da janela a folga vale: e ela que o LED usa como limiar, e o
    // aparelho como margem da sirene. Os 15 criados batem no teto de 8.
    // Vencida a janela, some.
    expect(d.folgaTemperatura(t0 + 4 * 60 * 1000), 8);
    expect(d.folgaTemperatura(t0 + 6 * 60 * 1000), 0);

    // Diferenca 11, dentro da tolerancia (5) somada a folga (8).
    final evento = d.avaliarTemperatura(
      leitura: 121,
      ajuste: 132,
      nowMs: t0 + 4 * 60 * 1000,
    );
    expect(evento, isNull);
  });
}
