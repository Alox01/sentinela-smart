const CAMPOS_PERMITIDOS = new Set([
  'temperaturaMeta',
  'tempTimestamp',
  'umidadeMeta',
  'umidTimestamp',
  'modoSilencioso',
  'modoSilenciosoTimestamp',
  'comando',
  // Destino do comando. So roteia: nao e um ajuste em si, por isso nao conta
  // como conteudo ao verificar se o payload tem algo a aplicar.
  'idHardware',
]);

const LIMITE_TEMPERATURA_MIN = 60;
const LIMITE_TEMPERATURA_MAX = 200;
const LIMITE_UMIDADE_MIN = 0;
const LIMITE_UMIDADE_MAX = 100;

function isObjetoPlano(valor) {
  return valor !== null && typeof valor === 'object' && !Array.isArray(valor);
}

function isNumeroFinito(valor) {
  return typeof valor === 'number' && Number.isFinite(valor);
}

function isTimestampValido(valor) {
  return Number.isInteger(valor) && valor > 0;
}

function validarPayloadSincronizacao(payload) {
  const erros = [];

  if (!isObjetoPlano(payload)) {
    return {
      valido: false,
      erros: ['Payload deve ser um objeto JSON.'],
    };
  }

  const chaves = Object.keys(payload);
  if (chaves.filter((chave) => chave !== 'idHardware').length === 0) {
    erros.push('Payload nao pode ser vazio.');
  }

  for (const chave of chaves) {
    if (!CAMPOS_PERMITIDOS.has(chave)) {
      erros.push(`Campo desconhecido: ${chave}.`);
    }
  }

  if (
    Object.hasOwn(payload, 'idHardware') &&
    (typeof payload.idHardware !== 'string' || payload.idHardware.trim() === '')
  ) {
    erros.push('idHardware deve ser texto nao vazio quando informado.');
  }

  const temTemperatura = Object.hasOwn(payload, 'temperaturaMeta');
  const temTempTimestamp = Object.hasOwn(payload, 'tempTimestamp');
  const temUmidade = Object.hasOwn(payload, 'umidadeMeta');
  const temUmidTimestamp = Object.hasOwn(payload, 'umidTimestamp');
  const temModoSilencioso = Object.hasOwn(payload, 'modoSilencioso');
  const temModoTimestamp = Object.hasOwn(payload, 'modoSilenciosoTimestamp');
  const ehComandoLegadoSilenciar = payload.comando === 'silenciar';

  if (Object.hasOwn(payload, 'comando') && !ehComandoLegadoSilenciar) {
    erros.push('comando deve ser "silenciar" quando informado.');
  }

  if (temTemperatura !== temTempTimestamp) {
    erros.push('Ajuste de temperatura e tempTimestamp devem ser enviados juntos.');
  }
  if (temTemperatura) {
    if (!isNumeroFinito(payload.temperaturaMeta)) {
      erros.push('Ajuste de temperatura deve ser numero.');
    } else if (
      payload.temperaturaMeta < LIMITE_TEMPERATURA_MIN ||
      payload.temperaturaMeta > LIMITE_TEMPERATURA_MAX
    ) {
      erros.push(
        `Ajuste de temperatura deve estar entre ${LIMITE_TEMPERATURA_MIN} e ${LIMITE_TEMPERATURA_MAX}.`,
      );
    }
    if (!isTimestampValido(payload.tempTimestamp)) {
      erros.push('tempTimestamp deve ser inteiro positivo.');
    }
  }

  if (temUmidade !== temUmidTimestamp) {
    erros.push('Ajuste de umidade e umidTimestamp devem ser enviados juntos.');
  }
  if (temUmidade) {
    if (!isNumeroFinito(payload.umidadeMeta)) {
      erros.push('Ajuste de umidade deve ser numero.');
    } else if (
      payload.umidadeMeta < LIMITE_UMIDADE_MIN ||
      payload.umidadeMeta > LIMITE_UMIDADE_MAX
    ) {
      erros.push(
        `Ajuste de umidade deve estar entre ${LIMITE_UMIDADE_MIN} e ${LIMITE_UMIDADE_MAX}.`,
      );
    }
    if (!isTimestampValido(payload.umidTimestamp)) {
      erros.push('umidTimestamp deve ser inteiro positivo.');
    }
  }

  if (temModoSilencioso !== temModoTimestamp) {
    erros.push('modoSilencioso e modoSilenciosoTimestamp devem ser enviados juntos.');
  }
  if (temModoSilencioso) {
    if (typeof payload.modoSilencioso !== 'boolean') {
      erros.push('modoSilencioso deve ser boolean.');
    }
    if (!isTimestampValido(payload.modoSilenciosoTimestamp)) {
      erros.push('modoSilenciosoTimestamp deve ser inteiro positivo.');
    }
  }

  const temAlteracao =
    temTemperatura || temUmidade || temModoSilencioso || ehComandoLegadoSilenciar;
  if (!temAlteracao && chaves.length > 0) {
    erros.push('Payload nao contem uma alteracao reconhecida.');
  }

  return {
    valido: erros.length === 0,
    erros,
  };
}

function validarPayloadBotaoFisico(payload) {
  const erros = [];

  if (!isObjetoPlano(payload)) {
    return {
      valido: false,
      erros: ['Payload deve ser um objeto JSON.'],
    };
  }

  if (payload.tipo !== 'temp') {
    erros.push('tipo deve ser "temp".');
  }

  if (!isNumeroFinito(payload.valor)) {
    erros.push('valor deve ser numero.');
  } else if (
    payload.valor < LIMITE_TEMPERATURA_MIN ||
    payload.valor > LIMITE_TEMPERATURA_MAX
  ) {
    erros.push(
      `valor deve estar entre ${LIMITE_TEMPERATURA_MIN} e ${LIMITE_TEMPERATURA_MAX}.`,
    );
  }

  return {
    valido: erros.length === 0,
    erros,
  };
}

const FONTES_LEITURA_VALIDAS = new Set(['hardware', 'simulador', 'manual']);

// Valida uma leitura de telemetria recebida pela rota de ingestao (POST /leitura).
// Exige apenas os campos minimos; os demais sao opcionais para nao travar
// prototipos de hardware que enviem menos informacao.
function validarPayloadLeitura(payload) {
  const erros = [];

  if (!isObjetoPlano(payload)) {
    return {
      valido: false,
      erros: ['Payload deve ser um objeto JSON.'],
    };
  }

  if (!isNumeroFinito(payload.temperaturaAtual)) {
    erros.push('temperaturaAtual deve ser numero.');
  }
  if (!isNumeroFinito(payload.umidadeAtual)) {
    erros.push('umidadeAtual deve ser numero.');
  } else if (payload.umidadeAtual < 0 || payload.umidadeAtual > 100) {
    erros.push('umidadeAtual deve estar entre 0 e 100.');
  }

  if (
    Object.hasOwn(payload, 'timestampLeitura')
    && !isTimestampValido(payload.timestampLeitura)
  ) {
    erros.push('timestampLeitura deve ser inteiro positivo.');
  }

  if (Object.hasOwn(payload, 'fonte') && !FONTES_LEITURA_VALIDAS.has(payload.fonte)) {
    erros.push('fonte deve ser hardware, simulador ou manual.');
  }

  return {
    valido: erros.length === 0,
    erros,
  };
}

function aplicarSincronizacao(configLocal, payload, options = {}) {
  const now = options.now ?? Date.now;
  const alteracoesAplicadas = [];
  const alteracoesIgnoradas = [];
  const payloadNormalizado = { ...payload };

  if (payloadNormalizado.comando === 'silenciar') {
    payloadNormalizado.modoSilencioso = true;
    payloadNormalizado.modoSilenciosoTimestamp = now();
  }

  const aplicarCampo = (chaveValor, chaveTimestamp) => {
    if (!Object.hasOwn(payloadNormalizado, chaveValor)) return;

    const atualizou = configLocal.atualizarSeMaisRecente(
      chaveValor,
      payloadNormalizado[chaveValor],
      payloadNormalizado[chaveTimestamp],
    );

    if (atualizou) {
      alteracoesAplicadas.push(chaveValor);
    } else {
      alteracoesIgnoradas.push(chaveValor);
    }
  };

  aplicarCampo('temperaturaMeta', 'tempTimestamp');
  aplicarCampo('umidadeMeta', 'umidTimestamp');
  aplicarCampo('modoSilencioso', 'modoSilenciosoTimestamp');

  return {
    sucesso: true,
    alteracoesAplicadas,
    alteracoesIgnoradas,
    configAtualizada: configLocal,
  };
}

module.exports = {
  aplicarSincronizacao,
  validarPayloadBotaoFisico,
  validarPayloadLeitura,
  validarPayloadSincronizacao,
};
