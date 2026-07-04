const test = require('node:test');
const assert = require('node:assert/strict');

const {
  INTERVALO_KEEP_ALIVE_PADRAO_MS,
  iniciarKeepAlive,
} = require('../keep_alive');

test('nao agenda quando a URL esta vazia', () => {
  const timer = iniciarKeepAlive({
    url: '  ',
    setIntervalFn: () => {
      throw new Error('nao deve agendar');
    },
  });
  assert.equal(timer, null);
});

test('agenda ping periodico no endpoint /status', async () => {
  const chamadas = [];
  let callbackAgendado = null;
  let intervaloRecebido = null;
  const timer = { unrefChamado: false, unref() { this.unrefChamado = true; } };

  const retorno = iniciarKeepAlive({
    url: 'https://estufa.onrender.com/',
    fetchFn: async (endpoint) => {
      chamadas.push(endpoint);
    },
    setIntervalFn(callback, intervalo) {
      callbackAgendado = callback;
      intervaloRecebido = intervalo;
      return timer;
    },
    logger: { error() {} },
  });

  assert.equal(retorno, timer);
  assert.equal(timer.unrefChamado, true);
  assert.equal(intervaloRecebido, INTERVALO_KEEP_ALIVE_PADRAO_MS);

  await callbackAgendado();
  assert.deepEqual(chamadas, ['https://estufa.onrender.com/status']);
});

test('falha no ping nao derruba o agendador', async () => {
  const erros = [];
  let callbackAgendado = null;

  iniciarKeepAlive({
    url: 'https://estufa.onrender.com',
    fetchFn: async () => {
      throw new Error('sem rede');
    },
    setIntervalFn(callback) {
      callbackAgendado = callback;
      return { unref() {} };
    },
    logger: {
      error(...args) {
        erros.push(args.join(' '));
      },
    },
  });

  await callbackAgendado();
  assert.match(erros.join(' '), /Keep-alive falhou/);
});
