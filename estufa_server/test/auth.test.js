const test = require('node:test');
const assert = require('node:assert/strict');
const { createAuthMiddleware } = require('../auth');

function criarReq(headers = {}) {
  return {
    get(name) {
      return headers[name.toLowerCase()];
    },
  };
}

function criarRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

test('nao bloqueia quando token nao esta configurado', () => {
  const middleware = createAuthMiddleware('');
  const req = criarReq();
  const res = criarRes();
  let nextChamado = false;

  middleware(req, res, () => {
    nextChamado = true;
  });

  assert.equal(nextChamado, true);
  assert.equal(res.statusCode, null);
});

test('aceita autenticacao via bearer', () => {
  const middleware = createAuthMiddleware('abc123');
  const req = criarReq({ authorization: 'Bearer abc123' });
  const res = criarRes();
  let nextChamado = false;

  middleware(req, res, () => {
    nextChamado = true;
  });

  assert.equal(nextChamado, true);
  assert.equal(res.statusCode, null);
});

test('aceita autenticacao via token do dispositivo', () => {
  const middleware = createAuthMiddleware('abc123');
  const req = criarReq({ 'x-device-token': 'abc123' });
  const res = criarRes();
  let nextChamado = false;

  middleware(req, res, () => {
    nextChamado = true;
  });

  assert.equal(nextChamado, true);
  assert.equal(res.statusCode, null);
});

test('bloqueia quando token estiver errado', () => {
  const middleware = createAuthMiddleware('abc123');
  const req = criarReq({ authorization: 'Bearer zzz' });
  const res = criarRes();
  let nextChamado = false;

  middleware(req, res, () => {
    nextChamado = true;
  });

  assert.equal(nextChamado, false);
  assert.equal(res.statusCode, 401);
  assert.equal(res.body?.erro, 'Nao autorizado');
});
