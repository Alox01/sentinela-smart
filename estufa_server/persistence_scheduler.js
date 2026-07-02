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
}) {
  if (!db?.estaHabilitado?.()) {
    return null;
  }

  const salvar = async () => {
    try {
      const resultado = await db.salvarSnapshot(simulador.lerCompleto());
      if (resultado?.salvo) {
        logger.log?.(`Leitura persistida no banco: ${resultado.motivo}.`);
      }
    } catch (error) {
      logger.error?.('Falha ao salvar snapshot no banco:', error.message);
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
