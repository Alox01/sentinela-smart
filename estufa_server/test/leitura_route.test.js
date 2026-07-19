const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

const { createEstufaRouter } = require('../routes/estufa_routes');

function criarApp({ db, buffer = null, simulador } = {}) {
  const app = express();
  app.use(express.json());
  app.use(
    createEstufaRouter({
      simulador: simulador || { lerCompleto: () => ({ simulador: true }) },
      db,
      authMiddleware: (_req, _res, next) => next(),
      buffer,
    }),
  );
  return app;
}

async function getStatus(app, query = '') {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    const resposta = await fetch(`http://127.0.0.1:${port}/status${query}`);
    return { status: resposta.status, body: await resposta.json() };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
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
  assert.deepEqual(body, {
    sucesso: true,
    persistido: true,
    motivo: 'primeira_leitura',
  });
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
    idHardware: 'ESP32_CAMPO_01',
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
    idHardware: 'ESP32_CAMPO_01',
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

test('atualiza estado ao vivo a cada leitura e poupa o historico comum', async () => {
  const persistidas = [];
  const app = criarApp({
    db: {
      estaHabilitado: () => true,
      async persistirLeituraBufferizada(dados) {
        persistidas.push(dados);
      },
    },
  });

  await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 90,
    umidadeAtual: 50,
  });
  const segunda = await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 91,
    umidadeAtual: 50,
  });
  const aoVivo = await getStatus(app, '?idHardware=ESP32_CAMPO_01');

  assert.equal(persistidas.length, 1);
  assert.equal(segunda.body.persistido, false);
  assert.equal(segunda.body.motivo, 'sem_mudanca_relevante');
  assert.equal(aoVivo.body.status.temperaturaAtual, 91);
});

test('POST /leitura exige aparelho e valida a configuracao recebida', async () => {
  const app = criarApp({ db: { estaHabilitado: () => false } });

  const semId = await postLeitura(app, {
    temperaturaAtual: 90,
    umidadeAtual: 50,
  });
  assert.equal(semId.status, 400);
  assert.ok(semId.body.detalhes.some((d) => d.includes('idHardware')));

  const configInvalida = await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 90,
    umidadeAtual: 50,
    config: { temperaturaMeta: 999, modoSilencioso: 'sim' },
  });
  assert.equal(configInvalida.status, 400);
  assert.ok(configInvalida.body.detalhes.some((d) => d.includes('temperaturaMeta')));
  assert.ok(configInvalida.body.detalhes.some((d) => d.includes('modoSilencioso')));
});
test('POST /leitura alimenta o /status daquele aparelho', async () => {
  const app = criarApp({ db: { estaHabilitado: () => false } });

  await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 142.5,
    umidadeAtual: 38,
    config: { idHardware: 'ESP32_CAMPO_01', temperaturaMeta: 140 },
  });

  const { status, body } = await getStatus(app, '?idHardware=ESP32_CAMPO_01');
  assert.equal(status, 200);
  assert.equal(body.status.idHardware, 'ESP32_CAMPO_01');
  assert.equal(body.status.temperaturaAtual, 142.5);
  assert.equal(body.config.temperaturaMeta, 140);
});

test('GET /status sem idHardware devolve o simulador', async () => {
  const app = criarApp({ db: { estaHabilitado: () => false } });
  const { status, body } = await getStatus(app, '');
  assert.equal(status, 200);
  assert.equal(body.simulador, true);
});

test('GET /status de aparelho desconhecido responde 404', async () => {
  const app = criarApp({ db: { estaHabilitado: () => false } });
  const { status } = await getStatus(app, '?idHardware=NAO_EXISTE');
  assert.equal(status, 404);
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

async function requisitar(app, caminho, opcoes = {}) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    const resposta = await fetch(`http://127.0.0.1:${port}${caminho}`, opcoes);
    return { status: resposta.status, body: await resposta.json() };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
}

function postSincronizar(app, corpo) {
  return requisitar(app, '/sincronizar', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(corpo),
  });
}

function simuladorEspiao() {
  const aplicados = [];
  return {
    aplicados,
    lerCompleto: () => ({ simulador: true }),
    sincronizarConfiguracao(config) {
      aplicados.push(config);
      return { sucesso: true, alteracoesAplicadas: Object.keys(config) };
    },
  };
}

test('POST /sincronizar de aparelho real nao aplica no simulador', async () => {
  const simulador = simuladorEspiao();
  const app = criarApp({ simulador, db: { salvarComandoSync: async () => {} } });

  const { status, body } = await postSincronizar(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaMeta: 80,
    tempTimestamp: 1000,
  });

  assert.equal(status, 200);
  assert.equal(body.sucesso, true);
  assert.equal(body.pendente, true);
  assert.equal(simulador.aplicados.length, 0);
});

test('POST /sincronizar sem idHardware continua indo para o simulador', async () => {
  const simulador = simuladorEspiao();
  const app = criarApp({ simulador, db: { salvarComandoSync: async () => {} } });

  const { status, body } = await postSincronizar(app, {
    temperaturaMeta: 80,
    tempTimestamp: 1000,
  });

  assert.equal(status, 200);
  assert.equal(body.pendente, undefined);
  assert.equal(simulador.aplicados.length, 1);
});

test('GET /comandos entrega o comando ate o aparelho confirmar', async () => {
  const simulador = simuladorEspiao();
  const app = criarApp({
    simulador,
    db: { estaHabilitado: () => false, salvarComandoSync: async () => {} },
  });

  await postSincronizar(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaMeta: 80,
    tempTimestamp: 1000,
  });

  const primeira = await requisitar(app, '/comandos?idHardware=ESP32_CAMPO_01');
  assert.equal(primeira.status, 200);
  assert.equal(primeira.body.comando.temperaturaMeta, 80);
  assert.equal(primeira.body.comando.tempTimestamp, 1000);
  // O destino nao volta no comando: o aparelho ja sabe quem e.
  assert.equal(primeira.body.comando.idHardware, undefined);

  // Buscar nao confirma nada: se o aparelho reiniciar antes de aplicar, o
  // comando precisa continuar la.
  const segunda = await requisitar(app, '/comandos?idHardware=ESP32_CAMPO_01');
  assert.equal(segunda.body.comando.temperaturaMeta, 80);

  // O aparelho reporta a config ja com o ajuste: agora sim esta obedecido.
  await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 90,
    umidadeAtual: 50,
    config: { temperaturaMeta: 80, tempTimestamp: 1000 },
  });

  const terceira = await requisitar(app, '/comandos?idHardware=ESP32_CAMPO_01');
  assert.equal(terceira.body.comando, null);
});

test('GET /status mostra o ajuste pendente antes de o aparelho confirmar', async () => {
  const simulador = simuladorEspiao();
  const app = criarApp({
    simulador,
    db: { estaHabilitado: () => false, salvarComandoSync: async () => {} },
  });

  await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 90,
    umidadeAtual: 50,
    config: { temperaturaMeta: 70, tempTimestamp: 500 },
  });

  await postSincronizar(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaMeta: 80,
    tempTimestamp: 1000,
  });

  // Sem isso a tela voltaria para 70 poucos segundos depois do comando.
  const pendente = await getStatus(app, '?idHardware=ESP32_CAMPO_01');
  assert.equal(pendente.body.config.temperaturaMeta, 80);
  assert.equal(pendente.body.aguardandoAparelho, true);

  await postLeitura(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 90,
    umidadeAtual: 50,
    config: { temperaturaMeta: 80, tempTimestamp: 1000 },
  });

  const confirmado = await getStatus(app, '?idHardware=ESP32_CAMPO_01');
  assert.equal(confirmado.body.config.temperaturaMeta, 80);
  assert.equal(confirmado.body.aguardandoAparelho, false);
});

test('GET /comandos nao entrega o comando de outro aparelho', async () => {
  const simulador = simuladorEspiao();
  const app = criarApp({ simulador, db: { salvarComandoSync: async () => {} } });

  await postSincronizar(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaMeta: 80,
    tempTimestamp: 1000,
  });

  const { body } = await requisitar(app, '/comandos?idHardware=ESP32_CAMPO_02');
  assert.equal(body.comando, null);
});

test('comandos do mesmo campo se sobrepoem, campos diferentes convivem', async () => {
  const simulador = simuladorEspiao();
  const app = criarApp({ simulador, db: { salvarComandoSync: async () => {} } });

  await postSincronizar(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaMeta: 80,
    tempTimestamp: 1000,
  });
  await postSincronizar(app, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaMeta: 90,
    tempTimestamp: 2000,
  });
  await postSincronizar(app, {
    idHardware: 'ESP32_CAMPO_01',
    modoSilencioso: true,
    modoSilenciosoTimestamp: 3000,
  });

  const { body } = await requisitar(app, '/comandos?idHardware=ESP32_CAMPO_01');
  assert.equal(body.comando.temperaturaMeta, 90);
  assert.equal(body.comando.tempTimestamp, 2000);
  assert.equal(body.comando.modoSilencioso, true);
});

test('GET /comandos sem idHardware responde 400', async () => {
  const app = criarApp({ db: {} });
  const { status } = await requisitar(app, '/comandos');
  assert.equal(status, 400);
});

test('leituras exigem token quando a autenticacao esta ativa', async () => {
  const bloqueia = (_req, res, _next) =>
    res.status(401).json({ erro: 'Nao autorizado' });
  const app = express();
  app.use(express.json());
  app.use(
    createEstufaRouter({
      simulador: { lerCompleto: () => ({ simulador: true }) },
      db: { estaHabilitado: () => false },
      authMiddleware: bloqueia,
    }),
  );

  // Telemetria e dado do produtor: sem token, nenhuma rota de leitura responde.
  for (const caminho of ['/status', '/historico', '/', '/dados']) {
    const { status } = await requisitar(app, caminho);
    assert.equal(status, 401, `esperava 401 em ${caminho}`);
  }
});

test('POST /leitura rejeita idHardware gigante', async () => {
  const app = criarApp({ db: { estaHabilitado: () => false } });
  const { status } = await postLeitura(app, {
    idHardware: 'X'.repeat(500),
    temperaturaAtual: 90,
    umidadeAtual: 50,
  });
  assert.equal(status, 400);
});

test('comando pendente sobrevive a um restart do servidor', async () => {
  // Banco falso com a mesma superficie da caixa persistida.
  const guardados = new Map();
  const dbFalso = {
    estaHabilitado: () => true,
    async persistirLeituraBufferizada() { return true; },
    async salvarComandoSync() {},
    async salvarComandoPendente(id, payload) { guardados.set(id, payload); },
    async removerComandoPendente(id) { guardados.delete(id); },
    async carregarComandosPendentes() {
      return [...guardados].map(([idHardware, comando]) => ({ idHardware, comando }));
    },
  };

  const app1 = criarApp({ simulador: simuladorEspiao(), db: dbFalso });
  await postSincronizar(app1, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaMeta: 85,
    tempTimestamp: 5000,
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(guardados.get('ESP32_CAMPO_01').temperaturaMeta, 85);

  // "Restart": um router novo, memoria zerada, mesmo banco.
  const app2 = criarApp({ simulador: simuladorEspiao(), db: dbFalso });
  await new Promise((resolve) => setImmediate(resolve));

  const { body } = await requisitar(app2, '/comandos?idHardware=ESP32_CAMPO_01');
  assert.equal(body.comando.temperaturaMeta, 85);

  // A confirmacao do aparelho limpa a copia persistida tambem.
  await postLeitura(app2, {
    idHardware: 'ESP32_CAMPO_01',
    temperaturaAtual: 90,
    umidadeAtual: 50,
    config: { temperaturaMeta: 85, tempTimestamp: 5000 },
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(guardados.has('ESP32_CAMPO_01'), false);
});

test('GET /versao responde sem token e informa o commit', async () => {
  const bloqueia = (_req, res, _next) =>
    res.status(401).json({ erro: 'Nao autorizado' });
  const app = express();
  app.use(express.json());
  app.use(
    createEstufaRouter({
      simulador: { lerCompleto: () => ({ simulador: true }) },
      db: { estaHabilitado: () => false },
      authMiddleware: bloqueia,
    }),
  );

  const { status, body } = await requisitar(app, '/versao');
  assert.equal(status, 200);
  assert.ok(Object.hasOwn(body, 'commit'));
  assert.ok(body.uptimeSegundos >= 0);
});
