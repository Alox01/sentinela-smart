const test = require('node:test');
const assert = require('node:assert/strict');
const { ConfiguracaoAlvo } = require('../classes');
const {
  aplicarSincronizacao,
  validarPayloadBotaoFisico,
  validarPayloadLeitura,
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

test('buzzerAtivo exige timestamp e segue o LWW', () => {
  const config = new ConfiguracaoAlvo('ESP32_TESTE');

  const valido = validarPayloadSincronizacao({
    buzzerAtivo: false,
    buzzerTimestamp: 5000,
  });
  const semTimestamp = validarPayloadSincronizacao({ buzzerAtivo: false });
  assert.equal(valido.valido, true, JSON.stringify(valido.erros));
  assert.equal(semTimestamp.valido, false);

  const novo = aplicarSincronizacao(config, {
    buzzerAtivo: false,
    buzzerTimestamp: 5000,
  });
  const antigo = aplicarSincronizacao(config, {
    buzzerAtivo: true,
    buzzerTimestamp: 4000,
  });
  assert.deepEqual(novo.alteracoesAplicadas, ['buzzerAtivo']);
  assert.deepEqual(antigo.alteracoesIgnoradas, ['buzzerAtivo']);
  assert.equal(config.buzzerAtivo, false);
});

test('rejeita ajustes fora da faixa operacional', () => {
  const temperaturaBaixa = validarPayloadSincronizacao({
    temperaturaMeta: 40,
    tempTimestamp: 1000,
  });
  const temperaturaAlta = validarPayloadSincronizacao({
    temperaturaMeta: 250,
    tempTimestamp: 1000,
  });
  const umidadeAlta = validarPayloadSincronizacao({
    umidadeMeta: 120,
    umidTimestamp: 1000,
  });

  assert.equal(temperaturaBaixa.valido, false);
  assert.equal(temperaturaAlta.valido, false);
  assert.equal(umidadeAlta.valido, false);
  assert.match(temperaturaAlta.erros.join(' '), /entre 50 e 200/);
  assert.match(umidadeAlta.erros.join(' '), /entre 0 e 100/);
});

test('valida payload do botao fisico simulado', () => {
  const valido = validarPayloadBotaoFisico({ tipo: 'temp', valor: 110 });
  const tipoInvalido = validarPayloadBotaoFisico({ tipo: 'umid', valor: 70 });
  const valorInvalido = validarPayloadBotaoFisico({ tipo: 'temp', valor: 500 });

  assert.equal(valido.valido, true);
  assert.equal(tipoInvalido.valido, false);
  assert.equal(valorInvalido.valido, false);
});

// Regressao: um ESP recem-gravado tem os timestamps em 0 (nunca recebeu
// comando). Exigir > 0 rejeitava toda leitura dele com HTTP 400, deixando o
// aparelho mudo na nuvem - e junto sumia o alerta de incendio.
test('aceita a leitura de um aparelho recem-gravado (timestamps zerados)', () => {
  const payload = {
    idHardware: 'ESP32_NOVO',
    temperaturaAtual: 124,
    umidadeAtual: 40,
  };
  const config = {
    temperaturaMeta: 117,
    tempTimestamp: 0,
    umidadeMeta: 90,
    umidTimestamp: 0,
    modoSilencioso: false,
    modoSilenciosoTimestamp: 0,
  };
  const r = validarPayloadLeitura(payload, config);
  assert.equal(r.valido, true, JSON.stringify(r.erros));
});

test('config invalida na leitura sai separada, sem derrubar a medicao', () => {
  const r = validarPayloadLeitura(
    { idHardware: 'ESP32_X', temperaturaAtual: 100, umidadeAtual: 50 },
    { temperaturaMeta: 117, tempTimestamp: -1 },
  );
  // D22: a medicao e valida e continua valida; o problema fica em `errosConfig`,
  // para quem chamou descartar so a configuracao.
  assert.equal(r.valido, true, JSON.stringify(r.erros));
  assert.ok(r.errosConfig.length > 0);
  assert.ok(r.errosConfig.some((e) => e.includes('tempTimestamp')));
});

test('ajuste abaixo do piso e config invalida, nao leitura invalida', () => {
  // O caso do campo foi 55 F vindo dos botoes, quando o piso era 60. O piso
  // virou 50 em 21/10/2026, entao 55 passou a ser legitimo e o teste usa 45 -
  // o que importa e a SEPARACAO, nao o numero.
  const r = validarPayloadLeitura(
    { idHardware: 'ESP32_215788', temperaturaAtual: 67, umidadeAtual: 72 },
    { temperaturaMeta: 45, tempTimestamp: 1 },
  );
  assert.equal(r.valido, true, JSON.stringify(r.erros));
  assert.ok(r.errosConfig.some((e) => e.includes('temperatura')));
});

test('comando ainda exige timestamp real (LWW nao aceita zero)', () => {
  const r = validarPayloadSincronizacao({ temperaturaMeta: 117, tempTimestamp: 0 });
  assert.equal(r.valido, false);
});
