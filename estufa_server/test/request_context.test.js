const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { criarContextoRequisicao } = require('../request_context');

test('devolve id da requisicao e registra somente metadados', () => {
  const mensagens = [];
  const log = {
    erro: (valor) => mensagens.push(['erro', valor]),
    info: (valor) => mensagens.push(['info', valor]),
    debug: (valor) => mensagens.push(['debug', valor]),
  };
  const req = { method: 'POST', path: '/sincronizar', body: { token: 'segredo' } };
  const res = new EventEmitter();
  res.statusCode = 200;
  res.setHeader = (nome, valor) => {
    res.headers = { ...res.headers, [nome]: valor };
  };
  const tempos = [1000, 1012];
  let chamouNext = false;

  criarContextoRequisicao({
    gerarId: () => 'req-123',
    agora: () => tempos.shift(),
    log,
  })(req, res, () => { chamouNext = true; });
  res.emit('finish');

  assert.equal(chamouNext, true);
  assert.equal(req.id, 'req-123');
  assert.equal(res.headers['X-Request-Id'], 'req-123');
  assert.deepEqual(mensagens, [
    ['debug', '[req-123] POST /sincronizar -> 200 (12ms)'],
  ]);
  assert.doesNotMatch(mensagens[0][1], /segredo/);
});

test('erros do cliente ficam em info e falhas do servidor em erro', () => {
  const niveis = [];
  const log = {
    erro: () => niveis.push('erro'),
    info: () => niveis.push('info'),
    debug: () => niveis.push('debug'),
  };
  for (const statusCode of [401, 503]) {
    const req = { method: 'GET', path: '/status' };
    const res = new EventEmitter();
    res.statusCode = statusCode;
    res.setHeader = () => {};
    criarContextoRequisicao({ gerarId: () => 'id', agora: () => 0, log })(
      req,
      res,
      () => {},
    );
    res.emit('finish');
  }
  assert.deepEqual(niveis, ['info', 'erro']);
});
