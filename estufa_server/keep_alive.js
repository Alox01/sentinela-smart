const INTERVALO_KEEP_ALIVE_PADRAO_MS = 10 * 60 * 1000;

// No plano gratuito do Render, o servico "dorme" apos ~15 minutos sem
// trafego, e a primeira requisicao seguinte demora ~50s para acordar. Este
// modulo faz o proprio servidor se pingar pela URL publica em intervalo menor
// que o de hibernacao, mantendo a nuvem acordada para o app responder rapido.
function iniciarKeepAlive({
  url,
  intervaloMs = INTERVALO_KEEP_ALIVE_PADRAO_MS,
  fetchFn = fetch,
  setIntervalFn = setInterval,
  logger = console,
}) {
  const alvo = String(url ?? '').trim();
  if (!alvo) return null;

  const endpoint = `${alvo.replace(/\/+$/, '')}/status`;

  const ping = async () => {
    try {
      await fetchFn(endpoint);
    } catch (error) {
      logger.error?.('Keep-alive falhou:', error.message);
    }
  };

  const timer = setIntervalFn(ping, intervaloMs);
  timer?.unref?.();
  return timer;
}

module.exports = {
  INTERVALO_KEEP_ALIVE_PADRAO_MS,
  iniciarKeepAlive,
};
