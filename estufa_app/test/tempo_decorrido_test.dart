import 'package:estufa_app/features/monitoramento/tempo_decorrido.dart';
import 'package:flutter_test/flutter_test.dart';

/// O "há quanto tempo" do aviso de sem comunicação.
///
/// É o texto que o produtor lê às 3h da manhã para decidir se levanta. Enquanto
/// era um método privado dentro de um arquivo de 1.200 linhas, nada aqui podia
/// ser afirmado.
void main() {
  final agora = DateTime(2026, 8, 4, 20);
  int hamMinutos(int m) =>
      agora.subtract(Duration(minutes: m)).millisecondsSinceEpoch;

  test('menos de um minuto não vira "0 min"', () {
    // "0 min" lê como defeito, e é justamente o estado mais comum: o aparelho
    // acabou de reportar.
    expect(formatarTempoDecorrido(hamMinutos(0), agora: agora), 'menos de 1 min');
  });

  test('relógio do aparelho adiantado não produz número negativo', () {
    // Acontece: o ESP sincroniza o NTP depois de subir, e por segundos o
    // timestamp dele fica à frente do celular. "-1 min" seria alarmante e falso.
    final futuro = agora.add(const Duration(seconds: 30)).millisecondsSinceEpoch;
    expect(formatarTempoDecorrido(futuro, agora: agora), 'menos de 1 min');
  });

  test('até uma hora, conta em minutos', () {
    expect(formatarTempoDecorrido(hamMinutos(1), agora: agora), '1 min');
    expect(formatarTempoDecorrido(hamMinutos(59), agora: agora), '59 min');
  });

  test('hora cheia não arrasta "0min" atrás', () {
    expect(formatarTempoDecorrido(hamMinutos(60), agora: agora), '1h');
    expect(formatarTempoDecorrido(hamMinutos(180), agora: agora), '3h');
  });

  test('hora quebrada mostra as duas partes', () {
    expect(formatarTempoDecorrido(hamMinutos(61), agora: agora), '1h 1min');
    expect(formatarTempoDecorrido(hamMinutos(155), agora: agora), '2h 35min');
  });

  test('uma noite inteira ainda é legível', () {
    // O caso que motiva o aviso existir: o aparelho parou e ninguém viu.
    expect(formatarTempoDecorrido(hamMinutos(8 * 60 + 12), agora: agora), '8h 12min');
  });
}
