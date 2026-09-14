import '../../models/historico_leitura_entity.dart';

/// A leitura veio de um aparelho de verdade, ou e o zero de partida da tela?
///
/// Ate 14/09/2026 o app gravava no historico os valores da tela mesmo antes de
/// a primeira leitura chegar — todos em zero. Uma dessas, gravada ao encerrar a
/// estufada #22, fez o relatorio sair com temperatura final 0°F, umidade 0% e
/// "ajuste alterado de 70 para 0°F". O app parou de gravar isso, mas as que ja
/// estao no banco do celular continuam la; o relatorio as ignora.
///
/// Os quatro zerados ao mesmo tempo nao acontecem numa estufa: o ajuste nunca e
/// 0 e o sensor de temperatura sem leitura nem chega a gravar.
bool leituraValida(HistoricoLeituraEntity leitura) =>
    !(leitura.temperatura == 0 &&
        leitura.umidade == 0 &&
        leitura.temperaturaMeta == 0 &&
        leitura.umidadeMeta == 0);
