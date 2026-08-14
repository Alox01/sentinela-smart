/// A faixa de rede que o app pode oferecer ao preencher o endereço fixo.
///
/// O aparelho informa o `gatewayAprendido` — o gateway da **última rede em que
/// ele conseguiu entrar**. Enquanto ele é reconfigurado para a mesma rede, esse
/// número é a melhor fonte que existe: o celular está no ponto de acesso do
/// aparelho naquele momento e não tem como descobrir a faixa da casa.
///
/// Levar o aparelho para outro lugar torna esse número mentira. Aconteceu em
/// campo: o aparelho foi para a faculdade, o app ofereceu `192.168.1.` — o
/// gateway de CASA —, o último número foi completado, e o aparelho passou a
/// aplicar um endereço de outra rede. Ele associa no Wi-Fi normalmente, mas fica
/// sem gateway e sem DNS válidos: não alcança a nuvem, e ninguém o alcança
/// localmente. Nada dá erro; simplesmente não conversa.
///
/// Devolve `null` quando não há o que oferecer com honestidade.
String? prefixoOferecido({
  required String? gatewayAprendido,
  required String? ssidDoAparelho,
  required String ssidDigitado,
}) {
  final conhecida = ssidDoAparelho?.trim() ?? '';
  if (conhecida.isEmpty) return null;
  if (ssidDigitado.trim() != conhecida) return null;

  return prefixoDe(gatewayAprendido);
}

/// Os três primeiros números de um IPv4, com o ponto final. `null` se não for
/// um endereço.
String? prefixoDe(String? ip) {
  if (ip == null) return null;
  final partes = ip.split('.');
  if (partes.length != 4) return null;
  if (partes.any((parte) => int.tryParse(parte) == null)) return null;
  return '${partes.take(3).join('.')}.';
}
