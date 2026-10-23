import '../../models/historico_leitura_entity.dart';

/// A leitura veio do aparelho, e não é o zero de partida da tela.
///
/// Os quatro campos zerados ao mesmo tempo não acontecem numa estufa: o ajuste
/// nunca é 0. São registros gravados antes da primeira leitura chegar, que
/// ainda estão no banco do celular.
bool leituraValida(HistoricoLeituraEntity leitura) =>
    !(leitura.temperatura == 0 &&
        leitura.umidade == 0 &&
        leitura.temperaturaMeta == 0 &&
        leitura.umidadeMeta == 0);
