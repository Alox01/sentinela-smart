// Agendamentos de ajuste: "as 14h deixe o alvo em 120 F" ou "suba 10 F".
//
// Por que no servidor e nao no celular: o Android dispara a notificacao na hora
// marcada, mas nao roda codigo do app para ENVIAR o comando. Como o caso de uso e
// justamente o produtor estar longe, com o app fechado, quem troca o alvo tem de
// ser algo sempre ligado. Aqui o agendamento vencido cai na caixa de comandos que
// o aparelho ja consulta - o mesmo caminho de um ajuste feito a mao, entao nada
// de novo precisou ser ensinado ao firmware.
//
// O aviso ao produtor NAO sai daqui: e um alarme local no proprio celular, que
// funciona sem internet nenhuma. Este modulo so mexe no alvo, em silencio, para
// nao chegarem dois avisos da mesma coisa.

const LIMITE_TEMPERATURA_MIN = 60;
const LIMITE_TEMPERATURA_MAX = 200;
const LIMITE_UMIDADE_MIN = 0;
const LIMITE_UMIDADE_MAX = 100;
const INTERVALO_VERIFICACAO_PADRAO_MS = 30 * 1000;

/// Ja passou da hora de aplicar? Puro: sem relogio proprio, sem banco.
function estaDevido(agendamento, agoraMs) {
  const quando = Number(agendamento?.aplicarEmMs);
  if (!Number.isFinite(quando) || quando <= 0) return false;
  return agoraMs >= quando;
}

/// Traduz o agendamento no comando que vai para o aparelho, resolvendo o valor
/// relativo (`+10`) contra o ajuste VIGENTE no momento de aplicar - e por isso
/// que isso acontece aqui, e nao na hora de agendar: entre criar e vencer, o
/// produtor pode ter mexido no ajuste na estufa, e o "+10" dele significa "10 a
/// mais do que estiver", nao "10 a mais do que estava ontem".
///
/// Devolve null quando nao ha nada aplicavel (ex.: relativo sem ajuste
/// conhecido).
function resolverComando(agendamento, configAtual, agoraMs) {
  const comando = {};

  // O carimbo do LWW e a HORA AGENDADA, nao a hora em que este codigo rodou.
  // Um agendamento pode vencer atrasado (servidor fora do ar, por exemplo), e
  // carimbar com "agora" faria ele ganhar de um ajuste que o produtor tenha
  // feito a mao nesse meio tempo - desfazendo, sem aviso, uma decisao mais
  // recente que a dele. Com a hora agendada, o LWW resolve isso sozinho: o que
  // for mais novo vence, e o atrasado perde se ja houve algo depois.
  const quandoValido = Number.isFinite(Number(agendamento?.aplicarEmMs)) &&
    Number(agendamento.aplicarEmMs) > 0;
  const carimbo = quandoValido ? Number(agendamento.aplicarEmMs) : agoraMs;

  const alvoTemp = Number(configAtual?.temperaturaMeta);
  const alvoUmid = Number(configAtual?.umidadeMeta);

  if (Number.isFinite(Number(agendamento?.temperaturaMeta))) {
    comando.temperaturaMeta = Number(agendamento.temperaturaMeta);
  } else if (Number.isFinite(Number(agendamento?.temperaturaDelta))) {
    if (!Number.isFinite(alvoTemp)) return null;
    comando.temperaturaMeta = alvoTemp + Number(agendamento.temperaturaDelta);
  }

  if (Number.isFinite(Number(agendamento?.umidadeMeta))) {
    comando.umidadeMeta = Number(agendamento.umidadeMeta);
  } else if (Number.isFinite(Number(agendamento?.umidadeDelta))) {
    if (!Number.isFinite(alvoUmid)) return null;
    comando.umidadeMeta = alvoUmid + Number(agendamento.umidadeDelta);
  }

  if (comando.temperaturaMeta === undefined &&
      comando.umidadeMeta === undefined) {
    return null;
  }

  // Um relativo pode estourar o limite (alvo 195 + 10). Preso na borda em vez de
  // recusado: o produtor pediu "o mais quente que der", e recusar calado seria
  // pior do que entregar o maximo permitido.
  if (comando.temperaturaMeta !== undefined) {
    comando.temperaturaMeta = Math.min(
      LIMITE_TEMPERATURA_MAX,
      Math.max(LIMITE_TEMPERATURA_MIN, Math.round(comando.temperaturaMeta)),
    );
    comando.tempTimestamp = carimbo;
  }
  if (comando.umidadeMeta !== undefined) {
    comando.umidadeMeta = Math.min(
      LIMITE_UMIDADE_MAX,
      Math.max(LIMITE_UMIDADE_MIN, Math.round(comando.umidadeMeta)),
    );
    comando.umidTimestamp = carimbo;
  }

  return comando;
}

/// Valida o que o app manda criar. Devolve `{ valido, erros }`.
function validarAgendamento(corpo, agoraMs) {
  const erros = [];
  const idHardware = corpo?.idHardware;
  if (typeof idHardware !== 'string' || idHardware.trim() === '') {
    erros.push('idHardware e obrigatorio.');
  }

  const quando = Number(corpo?.aplicarEmMs);
  if (!Number.isFinite(quando) || quando <= 0) {
    erros.push('aplicarEmMs deve ser um instante em milissegundos.');
  } else if (quando < agoraMs - 60 * 1000) {
    // Tolera um minuto de folga: o relogio do celular e o do servidor nunca
    // batem exatamente, e recusar por segundos seria arbitrario.
    erros.push('aplicarEmMs esta no passado.');
  }

  const temTemp = corpo?.temperaturaMeta !== undefined ||
    corpo?.temperaturaDelta !== undefined;
  const temUmid = corpo?.umidadeMeta !== undefined ||
    corpo?.umidadeDelta !== undefined;
  if (!temTemp && !temUmid) {
    erros.push('Informe temperatura ou umidade (valor ou variacao).');
  }

  if (corpo?.temperaturaMeta !== undefined &&
      corpo?.temperaturaDelta !== undefined) {
    erros.push('Escolha valor OU variacao de temperatura, nao os dois.');
  }
  if (corpo?.umidadeMeta !== undefined && corpo?.umidadeDelta !== undefined) {
    erros.push('Escolha valor OU variacao de umidade, nao os dois.');
  }

  if (corpo?.temperaturaMeta !== undefined) {
    const v = Number(corpo.temperaturaMeta);
    if (!Number.isFinite(v) || v < LIMITE_TEMPERATURA_MIN ||
        v > LIMITE_TEMPERATURA_MAX) {
      erros.push(
        `Temperatura deve estar entre ${LIMITE_TEMPERATURA_MIN} e ${LIMITE_TEMPERATURA_MAX}.`,
      );
    }
  }
  if (corpo?.umidadeMeta !== undefined) {
    const v = Number(corpo.umidadeMeta);
    if (!Number.isFinite(v) || v < LIMITE_UMIDADE_MIN ||
        v > LIMITE_UMIDADE_MAX) {
      erros.push(
        `Umidade deve estar entre ${LIMITE_UMIDADE_MIN} e ${LIMITE_UMIDADE_MAX}.`,
      );
    }
  }
  for (const campo of ['temperaturaDelta', 'umidadeDelta']) {
    if (corpo?.[campo] !== undefined && !Number.isFinite(Number(corpo[campo]))) {
      erros.push(`${campo} deve ser numero.`);
    }
  }

  return { valido: erros.length === 0, erros };
}

/// Roda a cada `intervaloMs` e aplica o que venceu. Recebe tudo por injecao para
/// ser testavel sem banco, sem rede e sem esperar o relogio.
function iniciarAgendador({
  listarAgendamentos,
  configDoAparelho,
  aplicarComando,
  remover,
  intervaloMs = INTERVALO_VERIFICACAO_PADRAO_MS,
  setIntervalFn = setInterval,
  agora = () => Date.now(),
  logger = console,
}) {
  if (typeof listarAgendamentos !== 'function' ||
      typeof aplicarComando !== 'function') {
    return null;
  }

  const verificar = async () => {
    try {
      const agoraMs = agora();
      for (const agendamento of (await listarAgendamentos()) ?? []) {
        if (!estaDevido(agendamento, agoraMs)) continue;

        const config = configDoAparelho?.(agendamento.idHardware);
        const comando = resolverComando(agendamento, config, agoraMs);

        // Relativo sem alvo conhecido (aparelho nunca reportou): espera a
        // proxima rodada em vez de descartar. Um "+10 F" sem saber de quanto
        // partir nao tem resposta certa, e chutar mexeria na estufa errado.
        if (comando === null) continue;

        aplicarComando(agendamento.idHardware, comando);
        await remover?.(agendamento.id);
      }
    } catch (erro) {
      // Agendador que derruba o servidor nao agenda nada.
      logger.error?.('Falha ao aplicar agendamentos:', erro.message);
    }
  };

  const timer = setIntervalFn(verificar, intervaloMs);
  timer?.unref?.();
  return { timer, verificar };
}

module.exports = {
  INTERVALO_VERIFICACAO_PADRAO_MS,
  estaDevido,
  iniciarAgendador,
  resolverComando,
  validarAgendamento,
};
