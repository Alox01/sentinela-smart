/// Quanto a estufada durou.
///
/// A fonte é o **ciclo**, que sabe quando começou e quando terminou. As leituras
/// são só o que se conseguiu gravar nesse meio-tempo, e usá-las como medida
/// errava duas vezes:
///
/// - **com filtro**, mostrava o intervalo do recorte em vez da estufada — um dia
///   filtrado aparecia como 10h porque só havia 10h de leitura naquele dia;
/// - **sem filtro nenhum**, encurtava a estufada sempre que faltava leitura na
///   ponta. Aparelho desligado, queda de energia ou internet fora e a secagem
///   passava a constar menor do que foi.
///
/// O segundo caso é o pior, porque não tem sintoma: o número simplesmente vem
/// menor, e só quem conferir contra o horário de início percebe.
///
/// [intervaloDasLeituras] é a saída para a estufada que não tem ciclo associado
/// — histórico antigo, gravado antes de existir ciclo. Aí o intervalo das
/// leituras é a única medida que existe.
Duration duracaoDaEstufada({
  required DateTime? inicioDoCiclo,
  required DateTime? fimDoCiclo,
  required Duration intervaloDasLeituras,
  DateTime? agora,
}) {
  if (inicioDoCiclo == null) return intervaloDasLeituras;

  // Estufada em andamento não tem fim: corre até agora.
  final fim = fimDoCiclo ?? agora ?? DateTime.now();
  final duracao = fim.difference(inicioDoCiclo);

  // Relógio do aparelho e do celular podem discordar, e um fim antes do início
  // viraria "-03:00 h" na tela. Zero é feio; negativo é quebrado.
  return duracao.isNegative ? Duration.zero : duracao;
}
