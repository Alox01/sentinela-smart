const { reprocessarBuffer } = require('./persistencia');

const INTERVALO_LEITURA_PADRAO_MS = 10 * 60 * 1000;

function lerIntervaloPersistencia(valor) {
  if (valor == null || String(valor).trim() === '') {
    return INTERVALO_LEITURA_PADRAO_MS;
  }

  const intervalo = Number(valor);
  if (!Number.isFinite(intervalo) || intervalo < 1000) {
    return INTERVALO_LEITURA_PADRAO_MS;
  }

  return Math.round(intervalo);
}

function iniciarPersistenciaPeriodica({
  db,
  simulador,
  intervaloMs = INTERVALO_LEITURA_PADRAO_MS,
  setIntervalFn = setInterval,
  logger = console,
  buffer = null,
}) {
  if (!db?.estaHabilitado?.()) {
    return null;
  }

  const salvar = async () => {
    // 1. Tenta reenviar leituras que ficaram no buffer durante uma queda da nuvem.
    if (buffer) {
      try {
        const reenviadas = await reprocessarBuffer({
          buffer,
          enviar: (registro) => db.persistirLeituraBufferizada(registro),
        });
        if (reenviadas > 0) {
          logger.log?.(`Buffer offline reenviado: ${reenviadas} leitura(s).`);
        }
      } catch (error) {
        logger.error?.('Falha ao reenviar buffer de leituras:', error.message);
      }
    }

    // 2. Persiste a leitura atual; se a nuvem falhar, guarda no buffer offline.
    const dados = simulador.lerCompleto();
    try {
      const resultado = await db.salvarSnapshot(dados);
      if (resultado?.salvo) {
        logger.log?.(`Leitura persistida no banco: ${resultado.motivo}.`);
      }
    } catch (error) {
      logger.error?.('Falha ao salvar snapshot no banco:', error.message);
      if (buffer) {
        try {
          await buffer.adicionar(dados);
          logger.log?.('Leitura guardada no buffer offline.');
        } catch (erroBuffer) {
          logger.error?.('Falha ao guardar leitura no buffer:', erroBuffer.message);
        }
      }
    }
  };

  salvar();
  const timer = setIntervalFn(salvar, intervaloMs);
  timer?.unref?.();
  return timer;
}

module.exports = {
  INTERVALO_LEITURA_PADRAO_MS,
  iniciarPersistenciaPeriodica,
  lerIntervaloPersistencia,
};
