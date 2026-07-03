const test = require('node:test');
const assert = require('node:assert/strict');

const { iniciarPushLeituras, montarEndpoint } = require('../esp32_virtual');

function criarBufferMemoria(iniciais = []) {
  const registros = [...iniciais];
  return {
    registros,
    async listar() {
      return [...registros];
    },
    async remover(qtd) {
      registros.splice(0, qtd);
    },
    async adicionar(dados) {
      registros.push(dados);
    },
  };
}

function respostaOk() {
  return { ok: true, status: 200 };
}

test('monta o endpoint /leitura sem barra dupla', () => {
  assert.equal(montarEndpoint('http://nuvem:3000'), 'http://nuvem:3000/leitura');
  assert.equal(montarEndpoint('http://nuvem:3000/'), 'http://nuvem:3000/leitura');
});

test('nao inicia quando alvoUrl esta vazio', () => {
  const timer = iniciarPushLeituras({
    lerStatus: () => ({}),
    alvoUrl: '',
    setIntervalFn: () => {
      throw new Error('nao deve agendar');
    },
  });
  assert.equal(timer, null);
});

test('empurra a leitura atual com token nos cabecalhos', async () => {
  const chamadas = [];
  const fetchFn = async (url, opcoes) => {
    chamadas.push({ url, opcoes });
    return respostaOk();
  };

  iniciarPushLeituras({
    lerStatus: () => ({ temperaturaAtual: 90, umidadeAtual: 50 }),
    alvoUrl: 'http://nuvem:3000',
    token: 'chave-123',
    intervaloMs: 1000,
    fetchFn,
    setIntervalFn: () => ({ unref() {} }),
    logger: { log() {}, error() {} },
  });

  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(chamadas.length, 1);
  assert.equal(chamadas[0].url, 'http://nuvem:3000/leitura');
  assert.equal(chamadas[0].opcoes.method, 'POST');
  assert.equal(chamadas[0].opcoes.headers.Authorization, 'Bearer chave-123');
  assert.equal(chamadas[0].opcoes.headers['X-Device-Token'], 'chave-123');
  assert.deepEqual(JSON.parse(chamadas[0].opcoes.body), {
    temperaturaAtual: 90,
    umidadeAtual: 50,
  });
});

test('guarda no buffer quando o alvo esta indisponivel', async () => {
  const buffer = criarBufferMemoria();
  const fetchFn = async () => {
    throw new Error('sem rede');
  };

  iniciarPushLeituras({
    lerStatus: () => ({ temperaturaAtual: 88, umidadeAtual: 40 }),
    alvoUrl: 'http://nuvem:3000',
    intervaloMs: 1000,
    buffer,
    fetchFn,
    setIntervalFn: () => ({ unref() {} }),
    logger: { log() {}, error() {} },
  });

  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(buffer.registros.length, 1);
  assert.equal(buffer.registros[0].temperaturaAtual, 88);
});

test('reenvia o buffer quando a rede volta antes de mandar a leitura nova', async () => {
  const buffer = criarBufferMemoria([{ temperaturaAtual: 70, umidadeAtual: 30 }]);
  const enviados = [];
  const fetchFn = async (_url, opcoes) => {
    enviados.push(JSON.parse(opcoes.body).temperaturaAtual);
    return respostaOk();
  };

  iniciarPushLeituras({
    lerStatus: () => ({ temperaturaAtual: 91, umidadeAtual: 55 }),
    alvoUrl: 'http://nuvem:3000',
    intervaloMs: 1000,
    buffer,
    fetchFn,
    setIntervalFn: () => ({ unref() {} }),
    logger: { log() {}, error() {} },
  });

  await new Promise((resolve) => setImmediate(resolve));

  // Primeiro drena a leitura antiga do buffer, depois manda a nova.
  assert.deepEqual(enviados, [70, 91]);
  assert.equal(buffer.registros.length, 0);
});

test('rejeicao HTTP (nao-2xx) tambem vai para o buffer', async () => {
  const buffer = criarBufferMemoria();
  const fetchFn = async () => ({ ok: false, status: 503 });

  iniciarPushLeituras({
    lerStatus: () => ({ temperaturaAtual: 100, umidadeAtual: 60 }),
    alvoUrl: 'http://nuvem:3000',
    intervaloMs: 1000,
    buffer,
    fetchFn,
    setIntervalFn: () => ({ unref() {} }),
    logger: { log() {}, error() {} },
  });

  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(buffer.registros.length, 1);
});
