const test = require('node:test');
const assert = require('node:assert/strict');
const {
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
    status: { ...statusBase, umidadeAtual: 64 },
    config: configBase,
    agoraMs: 60 * 1000,
  });

  assert.equal(decisao.salvar, true);
  assert.equal(decisao.motivo, 'desvio_relevante');
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
