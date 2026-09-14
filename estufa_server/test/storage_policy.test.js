const test = require('node:test');
const assert = require('node:assert/strict');
const {
  alarmeDoProcesso,
  criarRegistroLeitura,
  deveSalvarLeitura,
  statusParaLeituraPersistida,
} = require('../storage_policy');

const configBase = {
  temperaturaMeta: 100,
  tempTimestamp: 1000,
  umidadeMeta: 70,
  umidTimestamp: 1000,
};

const statusBase = {
  temperaturaAtual: 100,
  umidadeAtual: 70,
  alarmeAtivo: false,
  alertaIncendio: false,
  sinalWifi: 80,
};

test('salva a primeira leitura do dispositivo', () => {
  const decisao = deveSalvarLeitura({
    ultimaLeitura: null,
    status: statusBase,
    config: configBase,
    agoraMs: 0,
  });

  assert.equal(decisao.salvar, true);
  assert.equal(decisao.motivo, 'primeira_leitura');
});

test('ignora leitura repetida dentro do intervalo sem mudanca relevante', () => {
  const ultimaLeitura = criarRegistroLeitura(statusBase, configBase, 0);
  const decisao = deveSalvarLeitura({
    ultimaLeitura,
    status: statusBase,
    config: configBase,
    agoraMs: 60 * 1000,
  });

  assert.equal(decisao.salvar, false);
  assert.equal(decisao.motivo, 'sem_mudanca_relevante');
});

test('salva novamente apos 10 minutos', () => {
  const ultimaLeitura = criarRegistroLeitura(statusBase, configBase, 0);
  const decisao = deveSalvarLeitura({
    ultimaLeitura,
    status: statusBase,
    config: configBase,
    agoraMs: 10 * 60 * 1000,
  });

  assert.equal(decisao.salvar, true);
  assert.equal(decisao.motivo, 'intervalo');
});

test('salva quando o ajuste muda', () => {
  const ultimaLeitura = criarRegistroLeitura(statusBase, configBase, 0);
  const decisao = deveSalvarLeitura({
    ultimaLeitura,
    status: statusBase,
    config: { ...configBase, temperaturaMeta: 105, tempTimestamp: 2000 },
    agoraMs: 60 * 1000,
  });

  assert.equal(decisao.salvar, true);
  assert.equal(decisao.motivo, 'mudanca_ajuste');
});

test('salva quando o alarme muda de estado', () => {
  const ultimaLeitura = criarRegistroLeitura(statusBase, configBase, 0);
  const decisao = deveSalvarLeitura({
    ultimaLeitura,
    status: { ...statusBase, alarmeAtivo: true },
    config: configBase,
    agoraMs: 60 * 1000,
  });

  assert.equal(decisao.salvar, true);
  assert.equal(decisao.motivo, 'mudanca_alarme');
});

test('salva quando entra em desvio relevante', () => {
  const ultimaLeitura = criarRegistroLeitura(statusBase, configBase, 0);
  const decisao = deveSalvarLeitura({
    ultimaLeitura,
    status: { ...statusBase, umidadeAtual: 61 },
    config: configBase,
    agoraMs: 60 * 1000,
  });

  assert.equal(decisao.salvar, true);
  assert.equal(decisao.motivo, 'desvio_relevante');
});

// 8 ainda e normal, acima e abaixo: a mesma fronteira da sirene do aparelho.
test('diferenca de 8 nao e desvio relevante', () => {
  const ultimaLeitura = criarRegistroLeitura(statusBase, configBase, 0);
  for (const status of [
    { ...statusBase, temperaturaAtual: 108 },
    { ...statusBase, temperaturaAtual: 92 },
    { ...statusBase, umidadeAtual: 62 },
    { ...statusBase, umidadeAtual: 78 },
  ]) {
    const decisao = deveSalvarLeitura({
      ultimaLeitura,
      status,
      config: configBase,
      agoraMs: 60 * 1000,
    });
    assert.equal(decisao.salvar, false, JSON.stringify(status));
  }
});

test('normaliza valores antes de salvar no banco', () => {
  const leitura = statusParaLeituraPersistida({
    ...statusBase,
    temperaturaAtual: 1200,
    umidadeAtual: 108,
    sinalWifi: -10,
  });

  assert.equal(leitura.temperaturaAtual, 999);
  assert.equal(leitura.umidadeAtual, 100);
  assert.equal(leitura.sinalWifi, 0);
});

// 13/09/2026: buzzer desligado no aparelho, estufa 10 F abaixo do ajuste por duas
// horas, e o banco guardou tudo como sem alarme. A sirene e um canal; o registro
// e outro.
test('sirene desligada nao apaga o alarme do registro', () => {
  const semSirene = { alarmeAtivo: false, alertaTemperatura: true, alertaIncendio: false };
  assert.equal(alarmeDoProcesso(semSirene), true);

  const ultimaLeitura = criarRegistroLeitura(statusBase, configBase, 0);
  const decisao = deveSalvarLeitura({
    ultimaLeitura,
    status: { ...statusBase, ...semSirene },
    config: configBase,
    agoraMs: 60 * 1000,
  });
  assert.equal(decisao.motivo, 'mudanca_alarme');
});

test('fogo conta como alarme mesmo com a sirene silenciada', () => {
  assert.equal(
    alarmeDoProcesso({ alarmeAtivo: false, alertaTemperatura: false, perigoChama: true }),
    true,
  );
});

test('sem alertaTemperatura (simulador, firmware antigo), segue pela sirene', () => {
  assert.equal(alarmeDoProcesso({ alarmeAtivo: true }), true);
  assert.equal(alarmeDoProcesso({ alarmeAtivo: false }), false);
});
