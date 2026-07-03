const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

const { createEstufaRouter } = require('../routes/estufa_routes');

function criarAppTeste() {
  const app = express();
  const simulador = {
    lerCompleto() {
      return {
        status: {
          temperaturaAtual: 97.4,
          umidadeAtual: 63.8,
          alarmeAtivo: true,
          perigoChama: false,
          riscoIncendio: false,
          umidificadorLigado: false,
          aquecedorLigado: true,
        },
        config: {
          temperaturaMeta: 100,
          umidadeMeta: 65,
          modoSilencioso: false,
        },
      };
    },
  };

  app.use(
    createEstufaRouter({
      simulador,
      db: {},
      authMiddleware: (_req, _res, next) => next(),
      tokenConfigurado: true,
    }),
  );

  return app;
}

async function requisitar(pathname) {
  const app = criarAppTeste();
  const server = http.createServer(app);

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  try {
    const resposta = await fetch(`http://127.0.0.1:${port}${pathname}`);
    assert.equal(resposta.status, 200);
    return await resposta.json();
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
}

test('rota raiz entrega payload compativel com ESP32', async () => {
  const payload = await requisitar('/');

  assert.equal(payload.temperaturaF, 97.4);
  assert.equal(payload.umidade, 63.8);
  assert.equal(payload.temperaturaAlvoF, 100);
  assert.equal(payload.umidadeAlvo, 65);
  assert.equal(payload.alertaTemperatura, true);
  assert.equal(payload.ledControleLigado, true);
  assert.equal(payload.tokenConfigurado, true);
  assert.equal(payload.versaoFirmware, 'simulador-http-v1');
});

test('rota /dados entrega payload compativel com ESP32', async () => {
  const payload = await requisitar('/dados');

  assert.equal(payload.temperaturaF, 97.4);
  assert.equal(payload.umidade, 63.8);
  assert.equal(payload.ip, 'simulador');
});
