const test = require('node:test');
const assert = require('node:assert/strict');
const { ConfiguracaoAlvo } = require('../classes');
const {
  aplicarSincronizacao,
  validarPayloadSincronizacao,
} = require('../sync');

test('valida payload de temperatura com timestamp', () => {
  const validacao = validarPayloadSincronizacao({
    temperaturaMeta: 95,
    tempTimestamp: 1000,
  });

  assert.equal(validacao.valido, true);
  assert.deepEqual(validacao.erros, []);
});

test('rejeita payload vazio ou com tipo invalido', () => {
  const vazio = validarPayloadSincronizacao({});
  const invalido = validarPayloadSincronizacao({
    temperaturaMeta: '95',
    tempTimestamp: 1000,
  });

  assert.equal(vazio.valido, false);
  assert.equal(invalido.valido, false);
  assert.match(invalido.erros.join(' '), /Ajuste de temperatura deve ser numero/);
});

test('aplica configuracao mais recente e ignora antiga', () => {
  const config = new ConfiguracaoAlvo('ESP32_TESTE');
  config.temperaturaMeta = 90;
  config.tempTimestamp = 1000;

  const antigo = aplicarSincronizacao(config, {
    temperaturaMeta: 80,
    tempTimestamp: 999,
  });
  const novo = aplicarSincronizacao(config, {
    temperaturaMeta: 95,
    tempTimestamp: 1001,
  });

  assert.deepEqual(antigo.alteracoesIgnoradas, ['temperaturaMeta']);
  assert.deepEqual(novo.alteracoesAplicadas, ['temperaturaMeta']);
  assert.equal(config.temperaturaMeta, 95);
  assert.equal(config.tempTimestamp, 1001);
});

test('modo silencioso usa timestamp e tambem aceita comando legado', () => {
  const config = new ConfiguracaoAlvo('ESP32_TESTE');

  const novo = aplicarSincronizacao(config, {
    modoSilencioso: true,
    modoSilenciosoTimestamp: 2000,
  });
  const legado = aplicarSincronizacao(
    config,
    { comando: 'silenciar' },
    { now: () => 3000 },
  );

  assert.deepEqual(novo.alteracoesAplicadas, ['modoSilencioso']);
  assert.deepEqual(legado.alteracoesAplicadas, ['modoSilencioso']);
  assert.equal(config.modoSilencioso, true);
  assert.equal(config.modoSilenciosoTimestamp, 3000);
});
