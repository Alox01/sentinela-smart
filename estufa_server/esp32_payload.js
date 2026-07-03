function criarPayloadEsp32(dadosCompletos, origem = 'simulador') {
  const { status, config } = dadosCompletos;

  return {
    temperaturaF: arredondar(status.temperaturaAtual),
    umidade: arredondar(status.umidadeAtual),
    temperaturaAlvoF: Math.round(config.temperaturaMeta),
    umidadeAlvo: Math.round(config.umidadeMeta),
    margemF: 5,
    alertaTemperatura: Boolean(status.alarmeAtivo),
    alertaLuz: Boolean(status.perigoChama || status.riscoIncendio),
    mostrandoUmidade: Boolean(status.umidificadorLigado),
    modoAjuste: false,
    buzzerSilenciado: Boolean(config.modoSilencioso),
    ledControleLigado: Boolean(status.aquecedorLigado),
    leituraOk: true,
    ip: origem,
  };
}

function arredondar(valor) {
  return Math.round(Number(valor) * 10) / 10;
}

module.exports = {
  criarPayloadEsp32,
};
