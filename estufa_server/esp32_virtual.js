const { reprocessarBuffer } = require('./persistencia');

// ESP32 virtual: faz o simulador se comportar como o aparelho fisico real,
// empurrando leituras para a nuvem via POST /leitura em vez de ser lido por
// dentro do processo. Quando o alvo esta inacessivel (queda de internet), as
// leituras vao para um buffer local e sao reenviadas quando a conexao volta -
// exatamente o que o ESP32 real precisaria fazer no campo.
function montarEndpoint(alvoUrl) {
  return `${String(alvoUrl).replace(/\/+$/, '')}/leitura`;
}

function criarEnviador({ endpoint, token, fetchFn }) {
  const headers = { 'content-type': 'application/json' };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
    headers['X-Device-Token'] = token;
  }

  return async function enviar(status) {
    const resposta = await fetchFn(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(status),
    });

    if (!resposta.ok) {
      throw new Error(`POST /leitura respondeu HTTP ${resposta.status}`);
    }
    return resposta;
  };
}

function iniciarPushLeituras({
  lerStatus,
  alvoUrl,
  token = '',
  intervaloMs,
  buffer = null,
  fetchFn = fetch,
  setIntervalFn = setInterval,
  logger = console,
}) {
  if (!alvoUrl) {
    return null;
  }

  const endpoint = montarEndpoint(alvoUrl);
  const enviar = criarEnviador({ endpoint, token, fetchFn });

  const empurrar = async () => {
    // 1. Tenta drenar leituras que ficaram no buffer durante uma queda de rede.
    if (buffer) {
      try {
        const reenviadas = await reprocessarBuffer({ buffer, enviar });
        if (reenviadas > 0) {
          logger.log?.(`ESP32 virtual: buffer reenviado (${reenviadas} leitura(s)).`);
        }
      } catch (error) {
        logger.error?.('ESP32 virtual: falha ao reenviar buffer:', error.message);
      }
    }

    // 2. Envia a leitura atual; se o alvo cair, guarda no buffer para depois.
    const status = lerStatus();
    try {
      await enviar(status);
    } catch (error) {
      logger.error?.('ESP32 virtual: falha ao enviar leitura:', error.message);
      if (buffer) {
        try {
          await buffer.adicionar(status);
          logger.log?.('ESP32 virtual: leitura guardada no buffer local.');
        } catch (erroBuffer) {
          logger.error?.('ESP32 virtual: falha ao guardar no buffer:', erroBuffer.message);
        }
      }
    }
  };

  empurrar();
  const timer = setIntervalFn(empurrar, intervaloMs);
  timer?.unref?.();
  return timer;
}

module.exports = {
  iniciarPushLeituras,
  montarEndpoint,
};
