const test = require('node:test');
const assert = require('node:assert/strict');

const {
  INTERVALO_LEITURA_PADRAO_MS,
  iniciarPersistenciaPeriodica,
  lerIntervaloPersistencia,
} = require('../persistence_scheduler');

test('usa intervalo padrao quando valor nao foi configurado ou invalido', () => {
  assert.equal(lerIntervaloPersistencia(undefined), INTERVALO_LEITURA_PADRAO_MS);
  assert.equal(lerIntervaloPersistencia(''), INTERVALO_LEITURA_PADRAO_MS);
  assert.equal(lerIntervaloPersistencia('abc'), INTERVALO_LEITURA_PADRAO_MS);
  assert.equal(lerIntervaloPersistencia('999'), INTERVALO_LEITURA_PADRAO_MS);
  assert.equal(lerIntervaloPersistencia('1500'), 1500);
});

test('nao agenda persistencia quando banco esta desabilitado', () => {
  const timer = iniciarPersistenciaPeriodica({
    db: { estaHabilitado: () => false },
    simulador: { lerCompleto: () => ({}) },
    setIntervalFn: () => {
      throw new Error('nao deve agendar');
    },
    logger: { log() {}, error() {} },
  });

  assert.equal(timer, null);
});

test('salva imediatamente e agenda novas leituras quando banco esta habilitado', async () => {
  let salvarChamadas = 0;
  let intervaloRecebido = null;
  let callbackAgendado = null;
  const timer = {
    unrefCalled: false,
    unref() {
      this.unrefCalled = true;
    },
  };
  const db = {
    estaHabilitado: () => true,
    async salvarSnapshot(dados) {
      salvarChamadas += 1;
      assert.deepEqual(dados, { status: 'ok' });
      return { salvo: true, motivo: 'primeira_leitura' };
    },
  };
  const simulador = { lerCompleto: () => ({ status: 'ok' }) };
  const logger = {
    logs: [],
    errors: [],
    log(msg) {
      this.logs.push(msg);
    },
    error(...args) {
      this.errors.push(args);
    },
  };

  const returnedTimer = iniciarPersistenciaPeriodica({
    db,
    simulador,
    intervaloMs: 1234,
    setIntervalFn(callback, intervalo) {
      callbackAgendado = callback;
      intervaloRecebido = intervalo;
      return timer;
    },
    logger,
  });

  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(returnedTimer, timer);
  assert.equal(timer.unrefCalled, true);
  assert.equal(intervaloRecebido, 1234);
  assert.equal(salvarChamadas, 1);

  await callbackAgendado();

  assert.equal(salvarChamadas, 2);
  assert.match(logger.logs.join(' '), /primeira_leitura/);
  assert.equal(logger.errors.length, 0);
});

test('registra erro sem derrubar o agendador', async () => {
  const logger = {
    errors: [],
    log() {},
    error(...args) {
      this.errors.push(args);
    },
  };
  let callbackAgendado = null;

  iniciarPersistenciaPeriodica({
    db: {
      estaHabilitado: () => true,
      async salvarSnapshot() {
        throw new Error('falha teste');
      },
    },
    simulador: { lerCompleto: () => ({}) },
    setIntervalFn(callback) {
      callbackAgendado = callback;
      return { unref() {} };
    },
    logger,
  });

  await new Promise((resolve) => setImmediate(resolve));
  await callbackAgendado();

  assert.equal(logger.errors.length >= 1, true);
  assert.match(String(logger.errors[0].join(' ')), /Falha ao salvar snapshot/);
});
