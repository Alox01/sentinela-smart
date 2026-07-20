// Roda a limpeza de leituras antigas no boot e depois uma vez por dia. E a
// contrapartida na nuvem da retencao que o app ja faz localmente: sem ela, o
// banco so cresce e acaba estourando a cota do provedor.

const RETENCAO_PADRAO_DIAS = 300; // ~10 meses, alinhado com a retencao local do Isar
const INTERVALO_LIMPEZA_MS = 24 * 60 * 60 * 1000;

function lerDiasRetencao(valor) {
  if (valor == null || String(valor).trim() === '') {
    return RETENCAO_PADRAO_DIAS;
  }
  const dias = Number(valor);
  if (!Number.isFinite(dias) || dias < 1) {
    return RETENCAO_PADRAO_DIAS;
  }
  return Math.round(dias);
}

function iniciarRetencao({
  db,
  diasRetencao = RETENCAO_PADRAO_DIAS,
  intervaloMs = INTERVALO_LIMPEZA_MS,
  setIntervalFn = setInterval,
  logger = console,
}) {
  if (!db?.estaHabilitado?.() || !db.apagarLeiturasAntigas) {
    return null;
  }

  const limpar = async () => {
    try {
      const { apagadas } = await db.apagarLeiturasAntigas(diasRetencao);
      if (apagadas > 0) {
        logger.log?.(
          `Retencao: ${apagadas} leitura(s) com mais de ${diasRetencao} dias apagada(s).`,
        );
      }
    } catch (error) {
      // Falhar aqui nao pode derrubar o servidor: e faxina, nao caminho critico.
      logger.error?.('Falha na retencao de leituras:', error.message);
    }
  };

  limpar();
  const timer = setIntervalFn(limpar, intervaloMs);
  timer?.unref?.();
  return timer;
}

module.exports = {
  INTERVALO_LIMPEZA_MS,
  RETENCAO_PADRAO_DIAS,
  iniciarRetencao,
  lerDiasRetencao,
};
