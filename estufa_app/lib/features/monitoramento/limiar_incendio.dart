/// O limite de temperatura a partir do qual a estufa está pegando fogo.
///
/// ## Por que não é um número fixo
///
/// Era 175 °F em todo lugar. Aí apareceu a cura que trabalha ACIMA disso: com o
/// ajuste em 180, os 175 fixos diriam "incêndio" com a estufa fazendo
/// exatamente o que foi mandada fazer. O limite passou a acompanhar o ajuste
/// quando ele já é alto — e continua nos 175 para a curva normal, que é a
/// esmagadora maioria das estufadas.
///
/// ## Onde mais isto existe
///
/// Em dois lugares, e os três precisam concordar:
///
/// - firmware, `limiteFogoF()` em `sentinela_esp32.ino`;
/// - servidor, `logica.js`.
///
/// Já divergiram: até a versão que fechou isso (jul/2026), o aparelho usava 175
/// fixo enquanto o servidor já acompanhava o ajuste — com o ajuste em 172, a
/// sirene tocava aos 175 e a nuvem só avisava aos 177. **Mexeu aqui, mexa nos
/// três.** Não dá para importar um do outro: são três linguagens, e o aparelho
/// tem de decidir sozinho, sem rede.
double limiteFogoF(double temperaturaAjusteF) {
  return temperaturaAjusteF > 170 ? temperaturaAjusteF + 5 : 175;
}
