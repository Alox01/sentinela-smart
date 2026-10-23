/// Calcula o limiar de incêndio a partir do ajuste de temperatura.
///
/// A mesma regra deve ser mantida no firmware e em `estufa_server/logica.js`.
double limiteFogoF(double temperaturaAjusteF) {
  return temperaturaAjusteF > 170 ? temperaturaAjusteF + 5 : 175;
}
