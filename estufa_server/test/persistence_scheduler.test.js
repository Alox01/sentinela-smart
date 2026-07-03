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

test('guarda leitura no buffer quando a nuvem falha', async () => {
  const bufferizadas = [];
  const buffer = {
    async listar() {
      return [];
    },
    async remover() {},
    async adicionar(dados) {
      bufferizadas.push(dados);
    },
  };
  let callbackAgendado = null;

  iniciarPersistenciaPeriodica({
    db: {
      estaHabilitado: () => true,
      async salvarSnapshot() {
        throw new Error('nuvem fora');
      },
    },
    simulador: { lerCompleto: () => ({ status: 'leitura-atual' }) },
    setIntervalFn(callback) {
      callbackAgendado = callback;
      return { unref() {} };
    },
    logger: { log() {}, error() {} },
    buffer,
  });

  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(bufferizadas.length, 1);
  assert.deepEqual(bufferizadas[0], { status: 'leitura-atual' });

  await callbackAgendado();
  assert.equal(bufferizadas.length, 2);
});

test('reenvia o buffer antes de salvar quando a nuvem volta', async () => {
  const pendentes = [{ status: 'antiga-1' }, { status: 'antiga-2' }];
  const reenviadas = [];
  let removidas = 0;
  const buffer = {
    async listar() {
      return [...pendentes];
    },
    async remover(qtd) {
      removidas += qtd;
      pendentes.splice(0, qtd);
    },
    async adicionar() {
      throw new Error('nao deveria bufferizar');
    },
  };

  iniciarPersistenciaPeriodica({
    db: {
      estaHabilitado: () => true,
      async persistirLeituraBufferizada(registro) {
        reenviadas.push(registro.status);
        return true;
      },
      async salvarSnapshot() {
        return { salvo: true, motivo: 'intervalo' };
      },
    },
    simulador: { lerCompleto: () => ({ status: 'nova' }) },
    setIntervalFn: () => ({ unref() {} }),
    logger: { log() {}, error() {} },
    buffer,
  });

  await new Promise((resolve) => setImmediate(resolve));

  assert.deepEqual(reenviadas, ['antiga-1', 'antiga-2']);
  assert.equal(removidas, 2);
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
