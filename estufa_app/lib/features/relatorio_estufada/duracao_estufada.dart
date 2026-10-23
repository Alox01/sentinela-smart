/// Quanto a estufada durou.
///
/// Prioriza o intervalo registrado no ciclo. [intervaloDasLeituras] atende
/// registros antigos que não possuem ciclo associado.
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

  // Evita duração negativa quando os relógios do aparelho e do celular divergem.
  return duracao.isNegative ? Duration.zero : duracao;
}
