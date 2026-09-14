const INTERVALO_PADRAO_MS = 10 * 60 * 1000;
// Desvio que antecipa a gravacao: acima de 8, a mesma fronteira da sirene do
// aparelho, do LED e dos eventos do app. Estava em 5 (e com >=), e o banco
// guardava como desvio uma diferenca que o resto do sistema chamava de normal.
const LIMITE_TEMPERATURA_F = 8;
const LIMITE_UMIDADE_PERCENTUAL = 8;

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

// O ALARME DO PROCESSO - temperatura fora da faixa ou fogo -, e nao "a sirene
// esta tocando". E o que vai para a coluna de alarme do banco e o que antecipa a
// gravacao. Com `alarmeAtivo`, desligar o buzzer no aparelho apagava o alarme do
// historico: em 13/09/2026 a estufa passou duas horas 10 F abaixo do ajuste e o
// banco guardou tudo como sem alarme. Mesma regra que o push ja segue
// (`alertas_push.js`): o barulho na estufa e um canal, o registro e outro.
//
// `alertaTemperatura` so vem do aparelho de verdade; o simulador e firmware
// antigo seguem pelo `alarmeAtivo`, como antes.
function alarmeDoProcesso(status = {}) {
  if (typeof status.alertaTemperatura !== 'boolean') {
    return Boolean(status.alarmeAtivo ?? status.alertaIncendio);
  }
  return status.alertaTemperatura
    || status.alertaIncendio === true
    || status.perigoChama === true
    || status.riscoIncendio === true;
}

function desvioRelevante(status = {}, config = {}) {
  const temperatura = numeroSeguro(status.temperaturaAtual);
  const umidade = numeroSeguro(status.umidadeAtual);
  const temperaturaAjuste = numeroSeguro(config.temperaturaMeta, temperatura);
  const umidadeAjuste = numeroSeguro(config.umidadeMeta, umidade);

  return (
    Math.abs(temperatura - temperaturaAjuste) > LIMITE_TEMPERATURA_F
    || Math.abs(umidade - umidadeAjuste) > LIMITE_UMIDADE_PERCENTUAL
  );
}

function deveSalvarLeitura({ ultimaLeitura, status, config, agoraMs, intervaloMs = INTERVALO_PADRAO_MS }) {
  if (!ultimaLeitura) return { salvar: true, motivo: 'primeira_leitura' };

  const tempoUltima = numeroSeguro(ultimaLeitura.agoraMs);
  if (agoraMs - tempoUltima >= intervaloMs) {
    return { salvar: true, motivo: 'intervalo' };
  }

  const alarmeAtual = alarmeDoProcesso(status);
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
    alarmeAtivo: alarmeDoProcesso(status),
    assinaturaAjuste: assinaturaAjuste(config),
    desvioRelevante: desvioRelevante(status, config),
  };
}

module.exports = {
  INTERVALO_PADRAO_MS,
  alarmeDoProcesso,
  criarRegistroLeitura,
  deveSalvarLeitura,
  statusParaLeituraPersistida,
};
