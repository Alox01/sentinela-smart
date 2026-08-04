const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

const { criarRotasPush } = require('../routes/rotas_push');

// O cadastro de quem recebe aviso, sem teste ate agora.
//
// A falha desta area e silenciosa e ja aconteceu: uma estufa sem ninguem
// inscrito e IDENTICA a uma inscrita, na tela do app, e um aparelho ficou 24 h
// fora do ar sem nenhum aviso sair. O que estas rotas respondem decide se o app
// mostra "este celular nao sera avisado" ou nao mostra nada.

function criarApp(db = {}, push = {}) {
  const app = express();
  app.use(express.json());
  app.use(
    criarRotasPush({
      db,
      authMiddleware: (_req, _res, next) => next(),
      push,
      alertas: {},
    }),
  );
  return app;
}

async function chamar(app, caminho, opcoes = {}) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    const resposta = await fetch(`http://127.0.0.1:${port}${caminho}`, {
      ...opcoes,
      headers: { 'content-type': 'application/json', ...opcoes.headers },
      body: opcoes.body === undefined ? undefined : JSON.stringify(opcoes.body),
    });
    const texto = await resposta.text();
    return { status: resposta.status, corpo: texto ? JSON.parse(texto) : null };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
}

test('registrar exige tokenPush e idHardware', async () => {
  // Sem um dos dois nao ha inscricao: falta o celular a avisar ou o aparelho a
  // vigiar. Aceitar calado deixaria o app achando que esta coberto.
  const app = criarApp({ registrarDispositivoPush: async () => {} });

  const semToken = await chamar(app, '/push/dispositivos', {
    method: 'POST',
    body: { idHardware: 'ESP32_ABC' },
  });
  const semId = await chamar(app, '/push/dispositivos', {
    method: 'POST',
    body: { tokenPush: 'fcm-token' },
  });

  assert.equal(semToken.status, 400);
  assert.equal(semId.status, 400);
});

test('registrar guarda os dois sem espaco em volta', async () => {
  // Token com espaco e um token diferente para o banco: a mesma pessoa
  // apareceria duas vezes, e remover uma nao removeria a outra.
  let recebido = null;
  const app = criarApp({
    registrarDispositivoPush: async (dados) => {
      recebido = dados;
    },
  });

  const { status, corpo } = await chamar(app, '/push/dispositivos', {
    method: 'POST',
    body: {
      tokenPush: '  fcm-token  ',
      idHardware: '  ESP32_ABC  ',
      plataforma: 'android',
      nome: '  Estufa do Fundo  ',
    },
  });

  assert.equal(status, 200);
  assert.equal(corpo.registrado, true);
  assert.equal(recebido.tokenPush, 'fcm-token');
  assert.equal(recebido.idHardware, 'ESP32_ABC');
  assert.equal(recebido.nome, 'Estufa do Fundo');
});

test('nome em branco vira null, e nao string vazia', async () => {
  // O nome vai no titulo do push ("Estufa do Fundo: temperatura baixa"). Vazio
  // produziria um titulo comecando com dois pontos; null faz o servidor manter
  // o que ja tinha guardado.
  let recebido = null;
  const app = criarApp({
    registrarDispositivoPush: async (dados) => {
      recebido = dados;
    },
  });

  await chamar(app, '/push/dispositivos', {
    method: 'POST',
    body: { tokenPush: 'fcm', idHardware: 'ESP32_ABC', nome: '   ' },
  });

  assert.equal(recebido.nome, null);
});

test('sem banco, responde sucesso mas diz que NAO registrou', async () => {
  // A distincao importa: o app le `registrado` para mostrar "este celular nao
  // sera avisado". Um `sucesso: true` sozinho esconderia a estufa sem vigia.
  const app = criarApp({});

  const { status, corpo } = await chamar(app, '/push/dispositivos', {
    method: 'POST',
    body: { tokenPush: 'fcm', idHardware: 'ESP32_ABC' },
  });

  assert.equal(status, 200);
  assert.equal(corpo.registrado, false);
  assert.equal(corpo.motivo, 'sem_persistencia');
});

test('falha do banco vira 500', async () => {
  const app = criarApp({
    registrarDispositivoPush: async () => {
      throw new Error('conexao caiu');
    },
  });

  const { status } = await chamar(app, '/push/dispositivos', {
    method: 'POST',
    body: { tokenPush: 'fcm', idHardware: 'ESP32_ABC' },
  });

  assert.equal(status, 500);
});

test('sincronizar exige uma LISTA de aparelhos', async () => {
  // Um texto no lugar da lista apagaria todas as inscricoes daquele celular: a
  // reconciliacao entenderia "nao acompanho nenhuma".
  const app = criarApp({ reconciliarDispositivosPush: async () => ({ removidas: 0 }) });

  const { status } = await chamar(app, '/push/dispositivos/sincronizar', {
    method: 'POST',
    body: { tokenPush: 'fcm', idHardwares: 'ESP32_ABC' },
  });

  assert.equal(status, 400);
});

test('sincronizar com lista vazia e valido: o celular nao acompanha nada', async () => {
  // Nao e erro. Quem apagou todas as estufas do app tem de poder dizer isso,
  // senao as inscricoes ficam orfas para sempre.
  let recebido = null;
  const app = criarApp({
    reconciliarDispositivosPush: async (token, ids) => {
      recebido = { token, ids };
      return { removidas: 3 };
    },
  });

  const { status, corpo } = await chamar(app, '/push/dispositivos/sincronizar', {
    method: 'POST',
    body: { tokenPush: 'fcm', idHardwares: [] },
  });

  assert.equal(status, 200);
  assert.equal(corpo.removidas, 3);
  assert.deepEqual(recebido, { token: 'fcm', ids: [] });
});

test('remover exige o tokenPush', async () => {
  const app = criarApp({ removerDispositivoPush: async () => {} });

  const { status } = await chamar(app, '/push/dispositivos', {
    method: 'DELETE',
    body: { idHardware: 'ESP32_ABC' },
  });

  assert.equal(status, 400);
});

test('remover sem idHardware apaga a inscricao inteira do celular', async () => {
  // `null` no id significa "todas as estufas deste celular" — e o caminho de
  // quem desligou os avisos no aparelho todo, nao numa estufa so.
  let recebido = null;
  const app = criarApp({
    removerDispositivoPush: async (dados) => {
      recebido = dados;
    },
  });

  const { status } = await chamar(app, '/push/dispositivos', {
    method: 'DELETE',
    body: { tokenPush: 'fcm' },
  });

  assert.equal(status, 200);
  assert.deepEqual(recebido, { tokenPush: 'fcm', idHardware: null });
});
