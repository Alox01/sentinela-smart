const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const express = require('express');

const { createAuthMiddleware } = require('../auth');
const { criarRegistroDeChaves } = require('../chaves_aparelho');
const { createEstufaRouter } = require('../routes/estufa_routes');

const CHAVE_GLOBAL = 'chave-global-do-produtor';
const ID_A = 'ESP32_AAAA11';
const ID_B = 'ESP32_BBBB22';

// Banco falso com a MESMA semantica do de verdade: TOFU no registro (so grava se
// nao houver chave) e rotacao exigindo a chave antiga. Se o falso fosse mais
// permissivo, os testes de seguranca abaixo passariam sem provar nada.
function dbFalso(chavesIniciais = {}) {
  const chaves = new Map(Object.entries(chavesIniciais));
  return {
    chaves,
    estaHabilitado: () => false,
    async registrarChaveAparelho(idHardware, chave) {
      if (!idHardware || !chave) return { estado: 'invalido' };
      const guardada = chaves.get(idHardware);
      if (guardada) {
        return guardada === chave
          ? { estado: 'ja_registrada' }
          : { estado: 'conflito' };
      }
      chaves.set(idHardware, chave);
      return { estado: 'registrada' };
    },
    async rotacionarChaveAparelho(idHardware, antiga, nova) {
      if (chaves.get(idHardware) !== antiga) {
        return { estado: 'chave_antiga_nao_bate' };
      }
      chaves.set(idHardware, nova);
      return { estado: 'rotacionada' };
    },
    async carregarChavesAparelhos() {
      return new Map(chaves);
    },
    async carregarUltimaLeitura() {
      return null;
    },
  };
}

function criarApp({ db, tokenGlobal = CHAVE_GLOBAL }) {
  const chavesAparelhos = criarRegistroDeChaves({ db });
  const authMiddleware = createAuthMiddleware(tokenGlobal, {
    chaveDoAparelho: (id) => chavesAparelhos.chaveDe(id),
  });
  const app = express();
  app.use(express.json());
  app.use(
    createEstufaRouter({
      simulador: { lerCompleto: () => ({ status: {}, config: {} }) },
      db,
      authMiddleware,
      chavesAparelhos,
    }),
  );
  return app;
}

async function requisitar(app, caminho, opcoes = {}) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    const resposta = await fetch(`http://127.0.0.1:${port}${caminho}`, opcoes);
    let body = null;
    try {
      body = await resposta.json();
    } catch (_) {
      body = null;
    }
    return { status: resposta.status, body };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
}

function comChave(chave, corpo) {
  return {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${chave}`,
    },
    body: JSON.stringify(corpo),
  };
}

test('a chave global continua autorizando', async () => {
  const app = criarApp({ db: dbFalso() });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave',
    comChave(CHAVE_GLOBAL, { idHardware: ID_A, chave: 'chave-do-a' }),
  );
  assert.equal(status, 200);
});

test('a chave de um aparelho autoriza uma requisicao dele', async () => {
  const db = dbFalso({ [ID_A]: 'chave-do-a' });
  const app = criarApp({ db });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave',
    comChave('chave-do-a', { idHardware: ID_A, chave: 'chave-do-a' }),
  );
  assert.equal(status, 200);
});

// O ponto todo de ter chave por aparelho. Sem esta amarracao, qualquer chave
// registrada abriria qualquer estufa e o esquema nao separaria nada.
test('a chave do aparelho A nao autoriza mexer no aparelho B', async () => {
  const db = dbFalso({ [ID_A]: 'chave-do-a', [ID_B]: 'chave-do-b' });
  const app = criarApp({ db });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave/rotacionar',
    comChave('chave-do-a', {
      idHardware: ID_B,
      chaveAtual: 'chave-do-b',
      chaveNova: 'nova-do-b',
    }),
  );
  assert.equal(status, 401);
  assert.equal(db.chaves.get(ID_B), 'chave-do-b');
});

test('chave desconhecida e recusada', async () => {
  const app = criarApp({ db: dbFalso({ [ID_A]: 'chave-do-a' }) });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave',
    comChave('chave-inventada', { idHardware: ID_A, chave: 'outra' }),
  );
  assert.equal(status, 401);
});

// Sem idHardware na requisicao nao ha a que amarrar a chave do aparelho, entao
// so a global serve. Do contrario, uma chave qualquer autorizaria rotas que nao
// dizem de quem falam.
test('sem idHardware, a chave de aparelho nao serve', async () => {
  const app = criarApp({ db: dbFalso({ [ID_A]: 'chave-do-a' }) });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave',
    comChave('chave-do-a', { chave: 'sem-id' }),
  );
  assert.equal(status, 401);
});

test('TOFU: o primeiro registro vence e o segundo com chave diferente da 409', async () => {
  const db = dbFalso();
  const app = criarApp({ db });

  const primeiro = await requisitar(
    app,
    '/aparelhos/chave',
    comChave(CHAVE_GLOBAL, { idHardware: ID_A, chave: 'primeira' }),
  );
  assert.equal(primeiro.status, 200);
  assert.equal(primeiro.body.estado, 'registrada');

  const tomada = await requisitar(
    app,
    '/aparelhos/chave',
    comChave(CHAVE_GLOBAL, { idHardware: ID_A, chave: 'tentativa-de-roubo' }),
  );
  assert.equal(tomada.status, 409);
  assert.equal(db.chaves.get(ID_A), 'primeira');
});

// O aparelho reenvia a mesma chave a cada boot; isso nao pode virar erro.
test('registrar de novo a MESMA chave e aceito', async () => {
  const db = dbFalso();
  const app = criarApp({ db });
  await requisitar(
    app,
    '/aparelhos/chave',
    comChave(CHAVE_GLOBAL, { idHardware: ID_A, chave: 'a-mesma' }),
  );
  const repetido = await requisitar(
    app,
    '/aparelhos/chave',
    comChave(CHAVE_GLOBAL, { idHardware: ID_A, chave: 'a-mesma' }),
  );
  assert.equal(repetido.status, 200);
  assert.equal(repetido.body.estado, 'ja_registrada');
});

test('a rotacao exige a chave antiga', async () => {
  const db = dbFalso({ [ID_A]: 'chave-velha' });
  const app = criarApp({ db });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave/rotacionar',
    comChave(CHAVE_GLOBAL, {
      idHardware: ID_A,
      chaveAtual: 'chute',
      chaveNova: 'chave-nova',
    }),
  );
  assert.equal(status, 403);
  assert.equal(db.chaves.get(ID_A), 'chave-velha');
});

// O caso da venda: depois de rotacionar, quem sabia a antiga fica trancado fora.
test('depois da rotacao a chave velha para de valer', async () => {
  const db = dbFalso({ [ID_A]: 'chave-velha' });
  const app = criarApp({ db });

  const rotacao = await requisitar(
    app,
    '/aparelhos/chave/rotacionar',
    comChave('chave-velha', {
      idHardware: ID_A,
      chaveAtual: 'chave-velha',
      chaveNova: 'chave-nova',
    }),
  );
  assert.equal(rotacao.status, 200);
  assert.equal(db.chaves.get(ID_A), 'chave-nova');

  // A chave nova vale na hora, sem esperar o cache vencer.
  const comNova = await requisitar(
    app,
    '/aparelhos/chave',
    comChave('chave-nova', { idHardware: ID_A, chave: 'chave-nova' }),
  );
  assert.equal(comNova.status, 200);

  // E a velha, sem a global no meio, nao entra mais.
  const appSemGlobal = criarApp({ db, tokenGlobal: '' });
  const comVelha = await requisitar(
    appSemGlobal,
    '/aparelhos/chave',
    comChave('chave-velha', { idHardware: ID_A, chave: 'chave-velha' }),
  );
  assert.equal(comVelha.status, 401);
});

test('rotacionar para a mesma chave e recusado', async () => {
  const app = criarApp({ db: dbFalso({ [ID_A]: 'igual' }) });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave/rotacionar',
    comChave(CHAVE_GLOBAL, {
      idHardware: ID_A,
      chaveAtual: 'igual',
      chaveNova: 'igual',
    }),
  );
  assert.equal(status, 400);
});

// ---- Separacao por estrago: universal x chave do aparelho ----
// A universal fica compilada no firmware e por isso NAO e segredo. Ela abre o
// que faz pouco estrago; mexer na estufa exige a chave daquele aparelho.

function criarAppSeparado({ db }) {
  const chavesAparelhos = criarRegistroDeChaves({ db });
  const chaveDoAparelho = (id) => chavesAparelhos.chaveDe(id);
  const app = express();
  app.use(express.json());
  app.use(
    createEstufaRouter({
      simulador: { lerCompleto: () => ({ status: {}, config: {} }) },
      db,
      authMiddleware: createAuthMiddleware(CHAVE_GLOBAL, { chaveDoAparelho }),
      authComando: createAuthMiddleware(CHAVE_GLOBAL, {
        chaveDoAparelho,
        exigirChaveDoAparelho: true,
      }),
      chavesAparelhos,
    }),
  );
  return app;
}

function comando(chave, corpo) {
  return {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${chave}`,
    },
    body: JSON.stringify(corpo),
  };
}

test('a universal reporta leitura, porque isso faz pouco estrago', async () => {
  const app = criarAppSeparado({ db: dbFalso({ [ID_A]: 'chave-do-a' }) });
  const { status } = await requisitar(
    app,
    '/leitura',
    comando(CHAVE_GLOBAL, {
      idHardware: ID_A,
      temperaturaAtual: 100,
      umidadeAtual: 50,
    }),
  );
  assert.notEqual(status, 401);
});

// O ponto da separacao: quem extrair a universal do firmware nao pode mexer na
// estufa de ninguem.
test('a universal NAO muda o ajuste de um aparelho registrado', async () => {
  const app = criarAppSeparado({ db: dbFalso({ [ID_A]: 'chave-do-a' }) });
  const { status } = await requisitar(
    app,
    '/sincronizar',
    comando(CHAVE_GLOBAL, { idHardware: ID_A, temperaturaMeta: 200 }),
  );
  assert.equal(status, 401);
});

test('a chave do aparelho muda o ajuste dele', async () => {
  const app = criarAppSeparado({ db: dbFalso({ [ID_A]: 'chave-do-a' }) });
  const { status } = await requisitar(
    app,
    '/sincronizar',
    comando('chave-do-a', { idHardware: ID_A, temperaturaMeta: 120 }),
  );
  assert.notEqual(status, 401);
});

// Sem isto, adotar a separacao derrubaria na hora todo aparelho que ainda nao
// registrou a sua chave. Transitorio, e some quando todos tiverem a delas.
test('aparelho ainda sem chave registrada aceita a universal', async () => {
  const app = criarAppSeparado({ db: dbFalso() });
  const { status } = await requisitar(
    app,
    '/sincronizar',
    comando(CHAVE_GLOBAL, { idHardware: ID_B, temperaturaMeta: 120 }),
  );
  assert.notEqual(status, 401);
});

// O beco sem saida que motivou tudo: um aparelho que perdeu a chave propria
// precisa conseguir registrar a nova, ou fica na rede funcionando e mudo.
test('a universal registra a chave de um aparelho', async () => {
  const db = dbFalso();
  const app = criarAppSeparado({ db });
  const { status } = await requisitar(
    app,
    '/aparelhos/chave',
    comando(CHAVE_GLOBAL, { idHardware: ID_A, chave: 'nova-do-a' }),
  );
  assert.equal(status, 200);
  assert.equal(db.chaves.get(ID_A), 'nova-do-a');
});

// ---- Reconciliacao das inscricoes de push ----
// Apagar uma a uma nao basta: um DELETE perdido (sem internet, chave velha)
// deixava o vigia olhando aparelho que nao pertence a estufa nenhuma.

function dbPushReconciliavel(linhas) {
  let atuais = [...linhas];
  return {
    get linhas() {
      return atuais;
    },
    estaHabilitado: () => false,
    async reconciliarDispositivosPush(tokenPush, idHardwares) {
      const antes = atuais.length;
      atuais = atuais.filter(
        (l) => l.tokenPush !== tokenPush || idHardwares.includes(l.idHardware),
      );
      return { removidas: antes - atuais.length };
    },
  };
}

test('a reconciliacao apaga a inscricao de uma estufa que nao existe mais', async () => {
  const db = dbPushReconciliavel([
    { tokenPush: 'tok-1', idHardware: ID_A },
    { tokenPush: 'tok-1', idHardware: ID_B },
  ]);
  const app = criarApp({ db });

  const { status, body } = await requisitar(
    app,
    '/push/dispositivos/sincronizar',
    comChave(CHAVE_GLOBAL, { tokenPush: 'tok-1', idHardwares: [ID_A] }),
  );

  assert.equal(status, 200);
  assert.equal(body.removidas, 1);
  assert.deepEqual(db.linhas.map((l) => l.idHardware), [ID_A]);
});

// Um celular nao pode desinscrever outro por engano.
test('a reconciliacao nao toca nas inscricoes de outro celular', async () => {
  const db = dbPushReconciliavel([
    { tokenPush: 'tok-1', idHardware: ID_A },
    { tokenPush: 'tok-2', idHardware: ID_A },
  ]);
  const app = criarApp({ db });

  await requisitar(
    app,
    '/push/dispositivos/sincronizar',
    comChave(CHAVE_GLOBAL, { tokenPush: 'tok-1', idHardwares: [] }),
  );

  assert.deepEqual(db.linhas.map((l) => l.tokenPush), ['tok-2']);
});

test('lista ausente e recusada, para nao apagar tudo por engano', async () => {
  const db = dbPushReconciliavel([{ tokenPush: 'tok-1', idHardware: ID_A }]);
  const app = criarApp({ db });
  const { status } = await requisitar(
    app,
    '/push/dispositivos/sincronizar',
    comChave(CHAVE_GLOBAL, { tokenPush: 'tok-1' }),
  );
  assert.equal(status, 400);
  assert.equal(db.linhas.length, 1);
});
