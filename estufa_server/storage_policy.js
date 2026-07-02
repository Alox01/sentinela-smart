const INTERVALO_PADRAO_MS = 10 * 60 * 1000;
const LIMITE_TEMPERATURA_F = 5;
const LIMITE_UMIDADE_PERCENTUAL = 5;

function numeroSeguro(valor, padrao = 0) {
  const numero = Number(valor);
  return Number.isFinite(numero) ? numero : padrao;
}

function limitarNumero(valor, minimo, maximo) {
  return Math.min(maximo, Math.max(minimo, numeroSeguro(valor, minimo)));
}

function statusParaLeituraPersistida(status) {
  return {
    ...status,
    temperaturaAtual: limitarNumero(status.temperaturaAtual, -100, 999),
    umidadeAtual: limitarNumero(status.umidadeAtual, 0, 100),
    sinalWifi: status.sinalWifi == null ? null : limitarNumero(status.sinalWifi, 0, 100),
  };
}

function assinaturaAjuste(config = {}) {
  return [
    numeroSeguro(config.temperaturaMeta),
    numeroSeguro(config.tempTimestamp),
    numeroSeguro(config.umidadeMeta),
    numeroSeguro(config.umidTimestamp),
  ].join('|');
}

function alarmeAtivo(status = {}) {
  return Boolean(status.alarmeAtivo ?? status.alertaIncendio);
}

function desvioRelevante(status = {}, config = {}) {
  const temperatura = numeroSeguro(status.temperaturaAtual);
  const umidade = numeroSeguro(status.umidadeAtual);
  const temperaturaAjuste = numeroSeguro(config.temperaturaMeta, temperatura);
  const umidadeAjuste = numeroSeguro(config.umidadeMeta, umidade);

  return (
    Math.abs(temperatura - temperaturaAjuste) >= LIMITE_TEMPERATURA_F
    || Math.abs(umidade - umidadeAjuste) >= LIMITE_UMIDADE_PERCENTUAL
  );
}

function deveSalvarLeitura({ ultimaLeitura, status, config, agoraMs, intervaloMs = INTERVALO_PADRAO_MS }) {
  if (!ultimaLeitura) return { salvar: true, motivo: 'primeira_leitura' };

  const tempoUltima = numeroSeguro(ultimaLeitura.agoraMs);
  if (agoraMs - tempoUltima >= intervaloMs) {
    return { salvar: true, motivo: 'intervalo' };
  }

  const alarmeAtual = alarmeAtivo(status);
  if (alarmeAtual !== ultimaLeitura.alarmeAtivo) {
    return { salvar: true, motivo: 'mudanca_alarme' };
  }

  const ajusteAtual = assinaturaAjuste(config);
  if (ajusteAtual !== ultimaLeitura.assinaturaAjuste) {
    return { salvar: true, motivo: 'mudanca_ajuste' };
  }

  const desvioAtual = desvioRelevante(status, config);
  if (desvioAtual && !ultimaLeitura.desvioRelevante) {
    return { salvar: true, motivo: 'desvio_relevante' };
  }

  return { salvar: false, motivo: 'sem_mudanca_relevante' };
}

function criarRegistroLeitura(status, config, agoraMs) {
  return {
    agoraMs,
    alarmeAtivo: alarmeAtivo(status),
    assinaturaAjuste: assinaturaAjuste(config),
    desvioRelevante: desvioRelevante(status, config),
  };
}

module.exports = {
  INTERVALO_PADRAO_MS,
  criarRegistroLeitura,
  deveSalvarLeitura,
  statusParaLeituraPersistida,
};
