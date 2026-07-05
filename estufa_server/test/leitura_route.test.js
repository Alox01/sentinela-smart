const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

const { createEstufaRouter } = require('../routes/estufa_routes');

function criarApp({ db, buffer = null } = {}) {
  const app = express();
  app.use(express.json());
  app.use(
    createEstufaRouter({
      simulador: { lerCompleto: () => ({}) },
      db,
      authMiddleware: (_req, _res, next) => next(),
      buffer,
    }),
  );
  return app;
}

async function postLeitura(app, corpo) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  try {
    const resposta = await fetch(`http://127.0.0.1:${port}/leitura`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(corpo),
    });
    return { status: resposta.status, body: await resposta.json() };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
}

test('persiste leitura na nuvem e marca fonte hardware por padrao', async () => {
  const persistidas = [];
  const app = criarApp({
    db: {
      estaHabilitado: () => true,
      async persistirLeituraBufferizada(dados) {
        persistidas.push(dados);
        return true;
      },
    },
  });

  const { status, body } = await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 95.2,
    umidadeAtual: 60,
  });

  assert.equal(status, 200);
  assert.deepEqual(body, { sucesso: true, persistido: true });
  assert.equal(persistidas.length, 1);
  assert.equal(persistidas[0].status.fonte, 'hardware');
  assert.equal(persistidas[0].status.temperaturaAtual, 95.2);
});

test('guarda no buffer quando a nuvem esta indisponivel', async () => {
  const bufferizadas = [];
  const app = criarApp({
    db: {
      estaHabilitado: () => true,
      async persistirLeituraBufferizada() {
        throw new Error('sem conexao');
      },
    },
    buffer: {
      async adicionar(dados) {
        bufferizadas.push(dados);
      },
    },
  });

  const { status, body } = await postLeitura(app, {
    temperaturaAtual: 95.2,
    umidadeAtual: 60,
  });

  assert.equal(status, 200);
  assert.equal(body.persistido, false);
  assert.equal(body.motivo, 'bufferizado');
  assert.equal(bufferizadas.length, 1);
});

test('rejeita payload sem os campos minimos', async () => {
  const app = criarApp({
    db: { estaHabilitado: () => true, async persistirLeituraBufferizada() {} },
  });

  const { status, body } = await postLeitura(app, { umidadeAtual: 200 });

  assert.equal(status, 400);
  assert.equal(body.sucesso, false);
  assert.ok(body.detalhes.some((d) => d.includes('temperaturaAtual')));
  assert.ok(body.detalhes.some((d) => d.includes('umidadeAtual')));
});

test('quando a persistencia esta desabilitada apenas confirma sem gravar', async () => {
  const app = criarApp({ db: { estaHabilitado: () => false } });

  const { status, body } = await postLeitura(app, {
    temperaturaAtual: 90,
    umidadeAtual: 50,
  });

  assert.equal(status, 200);
  assert.deepEqual(body, {
    sucesso: true,
    persistido: false,
    motivo: 'persistencia_desabilitada',
  });
});

async function getHistorico(app, query) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    const resposta = await fetch(`http://127.0.0.1:${port}/historico${query}`);
    return { status: resposta.status, body: await resposta.json() };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
}

test('GET /historico retorna as leituras do periodo', async () => {
  const recebido = {};
  const app = criarApp({
    db: {
      estaHabilitado: () => true,
      async carregarHistorico(idHardware, opcoes) {
        recebido.idHardware = idHardware;
        recebido.opcoes = opcoes;
        return [{ timestampLeitura: 111, temperaturaAtual: 90, umidadeAtual: 50 }];
      },
    },
  });

  const { status, body } = await getHistorico(
    app,
    '?inicio=100&fim=200&idHardware=ESP32_X',
  );

  assert.equal(status, 200);
  assert.equal(body.persistencia, true);
  assert.equal(body.leituras.length, 1);
  assert.equal(recebido.idHardware, 'ESP32_X');
  assert.equal(recebido.opcoes.inicioMs, 100);
  assert.equal(recebido.opcoes.fimMs, 200);
});

test('GET /historico sem banco responde lista vazia', async () => {
  const app = criarApp({ db: { estaHabilitado: () => false } });
  const { status, body } = await getHistorico(app, '');
  assert.equal(status, 200);
  assert.deepEqual(body, { leituras: [], persistencia: false });
});
