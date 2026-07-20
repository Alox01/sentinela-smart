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
    d.registrarMudancaAjusteTemperatura(0, deslocamento: 10);
    expect(d.temperaturaEmAcomodacao(10 * min), isTrue);
    expect(d.temperaturaEmAcomodacao(21 * min), isFalse);

    // diferenca 10 (atencao) persistindo durante a acomodacao: sem evento
    d.avaliarTemperatura(leitura: 100, ajuste: 90, nowMs: 0);
    expect(
      d.avaliarTemperatura(leitura: 100, ajuste: 90, nowMs: 15 * min),
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
  test('folga da acomodacao acompanha o tamanho da mudanca', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;

    d.registrarMudancaAjusteTemperatura(t0, deslocamento: 1);
    expect(d.folgaTemperatura(t0), 1);

    final d2 = DetectorOscilacao();
    d2.registrarMudancaAjusteTemperatura(t0, deslocamento: -25);
    // Teto: um salto enorme nao cega o alerta por completo.
    expect(d2.folgaTemperatura(t0), 20);
  });

  test('fora da janela a folga zera', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    d.registrarMudancaAjusteTemperatura(t0, deslocamento: 10);
    expect(d.folgaTemperatura(t0 + 21 * 60 * 1000), 0);
  });

  test('desvio maior que a folga nao e suprimido pela acomodacao', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    // Mexeu 1 grau: folga 1, entao tolera ate 6 (5 + 1).
    d.registrarMudancaAjusteTemperatura(t0, deslocamento: 1);

    // Desvio de 8 (125 x 117) e maior que a folga: continua contando como
    // oscilacao e vira evento depois do tempo de atencao.
    var evento = d.avaliarTemperatura(leitura: 125, ajuste: 117, nowMs: t0);
    expect(evento, isNull); // ainda nao persistiu tempo suficiente
    evento = d.avaliarTemperatura(
      leitura: 125,
      ajuste: 117,
      nowMs: t0 + 11 * 60 * 1000,
    );
    expect(evento, isNotNull, reason: 'desvio pre-existente nao pode sumir');
  });

  test('desvio dentro da folga segue perdoado durante a janela', () {
    final d = DetectorOscilacao();
    const t0 = 1000000;
    // Saltou 15 graus: e esperado a estufa levar tempo para chegar la.
    d.registrarMudancaAjusteTemperatura(t0, deslocamento: 15);
    final evento = d.avaliarTemperatura(
      leitura: 130,
      ajuste: 117,
      nowMs: t0 + 11 * 60 * 1000,
    );
    expect(evento, isNull);
  });
}
