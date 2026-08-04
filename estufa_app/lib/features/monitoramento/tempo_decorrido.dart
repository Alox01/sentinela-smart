/// "Há quanto tempo", na forma como o produtor fala.
///
/// Sai da tela de monitoramento porque não depende de nada dela — recebe um
/// instante e devolve texto. Enquanto era um método privado de um arquivo de
/// 1.200 linhas não havia como afirmar nada sobre ele, e ele aparece no aviso
/// de "sem comunicação", que é o texto que o produtor lê às 3h da manhã para
/// decidir se levanta.
String formatarTempoDecorrido(int desdeMs, {DateTime? agora}) {
  final referencia = agora ?? DateTime.now();
  final minutos = (referencia.millisecondsSinceEpoch - desdeMs) ~/ 60000;
  // Nada de "0 min" nem de número negativo quando o relógio do aparelho está
  // adiantado em segundos: os dois leem como defeito.
  if (minutos < 1) return 'menos de 1 min';
  if (minutos < 60) return '$minutos min';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  // "2h" e não "2h 0min": a hora cheia é o caso mais comum de todos.
  return resto == 0 ? '${horas}h' : '${horas}h ${resto}min';
}
