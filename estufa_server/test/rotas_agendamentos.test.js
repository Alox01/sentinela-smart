const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

const { criarRotasAgendamentos } = require('../routes/rotas_agendamentos');

// As rotas de agendamento nunca tiveram teste proprio. Elas nasceram dentro do
// `estufa_routes.js` de 993 linhas e sairam para arquivo separado; os testes
// ficaram apontando para o conjunto, e a divisao deixou este pedaco sem nada.
//
// O que se prova aqui e o comportamento que o produtor sente: um agendamento
// recusado por falta de banco em vez de aceito e esquecido, e uma recusa que
// nao mente sobre o motivo. Agendamento perdido em silencio significa madrugada
// sem o ajuste que ele marcou.

function criarApp({ db = {}, estado = {}, simulador = {} } = {}) {
  const app = express();
  app.use(express.json());
  app.use(
    criarRotasAgendamentos({
      simulador: { sincronizarConfiguracao() {}, ...simulador },
      db,
      authMiddleware: (_req, _res, next) => next(),
      autorizarComando: (_req, _res, next) => next(),
      estado: { configVigente: () => ({}), guardarComandoPendente() {}, ...estado },
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
    return {
      status: resposta.status,
      corpo: texto ? JSON.parse(texto) : null,
    };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((erro) => (erro ? reject(erro) : resolve()));
    });
  }
}

const daquiUmaHora = () => Date.now() + 60 * 60 * 1000;

test('sem banco, o agendamento e RECUSADO em vez de aceito', async () => {
  // O caso que importa: aceitar aqui devolveria "sucesso" para algo que sumiria
  // no proximo reciclo do processo. O produtor iria dormir achando que o ajuste
  // das 3h esta marcado.
  const app = criarApp({ db: { estaHabilitado: () => false } });

  const { status, corpo } = await chamar(app, '/agendamentos', {
    method: 'POST',
    body: {
      idHardware: 'ESP32_ABC',
      aplicarEmMs: daquiUmaHora(),
      temperaturaMeta: 130,
    },
  });

  assert.equal(status, 503);
  assert.equal(corpo.sucesso, false);
  assert.equal(corpo.erro, 'sem_persistencia');
});

test('com banco, salva e devolve o id como texto', async () => {
  // Texto, e nao numero: o app guarda o id como String, e um numero vindo daqui
  // viraria "17" em um lado e 17 no outro, quebrando o cancelamento.
  let salvo = null;
  const app = criarApp({
    db: {
      estaHabilitado: () => true,
      salvarAgendamento: async (idHardware, aplicarEmMs, payload) => {
        salvo = { idHardware, aplicarEmMs, payload };
        return 17;
      },
    },
  });
  const quando = daquiUmaHora();

  const { status, corpo } = await chamar(app, '/agendamentos', {
    method: 'POST',
    body: {
      idHardware: '  ESP32_ABC  ',
      aplicarEmMs: quando,
      temperaturaMeta: '130',
    },
  });

  assert.equal(status, 200);
  assert.equal(corpo.sucesso, true);
  assert.equal(corpo.id, '17');
  assert.equal(salvo.idHardware, 'ESP32_ABC', 'o id do aparelho vai sem espaco');
  assert.equal(salvo.aplicarEmMs, quando);
  assert.equal(
    salvo.payload.temperaturaMeta,
    130,
    'o valor vai como numero, mesmo tendo chegado como texto',
  );
});

test('so os campos de ajuste conhecidos atravessam', async () => {
  // Repassar o corpo inteiro deixaria qualquer chave entrar no comando que vai
  // ao aparelho.
  let salvo = null;
  const app = criarApp({
    db: {
      estaHabilitado: () => true,
      salvarAgendamento: async (_id, _quando, payload) => {
        salvo = payload;
        return 1;
      },
    },
  });

  await chamar(app, '/agendamentos', {
    method: 'POST',
    body: {
      idHardware: 'ESP32_ABC',
      aplicarEmMs: daquiUmaHora(),
      umidadeDelta: -5,
      buzzerAtivo: false,
      qualquerCoisa: 'x',
    },
  });

  assert.deepEqual(Object.keys(salvo), ['umidadeDelta']);
});

test('agendamento invalido volta 400 com o motivo', async () => {
  const app = criarApp({
    db: { estaHabilitado: () => true, salvarAgendamento: async () => 1 },
  });

  const { status, corpo } = await chamar(app, '/agendamentos', {
    method: 'POST',
    body: { idHardware: 'ESP32_ABC', aplicarEmMs: Date.now() - 60000 },
  });

  assert.equal(status, 400);
  assert.equal(corpo.sucesso, false);
  assert.ok(Array.isArray(corpo.detalhes) && corpo.detalhes.length > 0);
});

test('falha do banco vira 500, e nao um sucesso mentiroso', async () => {
  const app = criarApp({
    db: {
      estaHabilitado: () => true,
      salvarAgendamento: async () => {
        throw new Error('conexao caiu');
      },
    },
  });

  const { status, corpo } = await chamar(app, '/agendamentos', {
    method: 'POST',
    body: {
      idHardware: 'ESP32_ABC',
      aplicarEmMs: daquiUmaHora(),
      temperaturaMeta: 130,
    },
  });

  assert.equal(status, 500);
  assert.equal(corpo.sucesso, false);
});

test('listar sem idHardware e recusado', async () => {
  // Sem o id, listar devolveria os agendamentos de outra estufa.
  const app = criarApp({ db: { listarAgendamentos: async () => [] } });

  const { status } = await chamar(app, '/agendamentos');

  assert.equal(status, 400);
});

test('listar devolve o que o banco tem, para aquele aparelho', async () => {
  let pedido = null;
  const app = criarApp({
    db: {
      listarAgendamentos: async (idHardware) => {
        pedido = idHardware;
        return [{ id: '1', aplicarEmMs: 123 }];
      },
    },
  });

  const { status, corpo } = await chamar(
    app,
    '/agendamentos?idHardware=ESP32_ABC',
  );

  assert.equal(status, 200);
  assert.equal(pedido, 'ESP32_ABC');
  assert.equal(corpo.agendamentos.length, 1);
});

test('sem banco, listar devolve vazio em vez de erro', async () => {
  // A tela abre mostrando "nenhum agendamento", que e verdade: sem banco nao ha
  // nenhum. Devolver erro faria a tela parecer quebrada.
  const app = criarApp({ db: {} });

  const { status, corpo } = await chamar(
    app,
    '/agendamentos?idHardware=ESP32_ABC',
  );

  assert.equal(status, 200);
  assert.deepEqual(corpo.agendamentos, []);
});

test('cancelar exige o idHardware, mesmo tendo o id do agendamento', async () => {
  // O id sozinho apagaria o agendamento de qualquer estufa que o adivinhasse.
  const app = criarApp({ db: { removerAgendamento: async () => true } });

  const { status } = await chamar(app, '/agendamentos/9', { method: 'DELETE' });

  assert.equal(status, 400);
});

test('cancelar passa os dois ao banco e devolve se removeu', async () => {
  let recebido = null;
  const app = criarApp({
    db: {
      removerAgendamento: async (id, idHardware) => {
        recebido = { id, idHardware };
        return false;
      },
    },
  });

  const { status, corpo } = await chamar(
    app,
    '/agendamentos/9?idHardware=ESP32_ABC',
    { method: 'DELETE' },
  );

  assert.equal(status, 200);
  assert.deepEqual(recebido, { id: '9', idHardware: 'ESP32_ABC' });
  assert.equal(
    corpo.sucesso,
    false,
    'nao removeu nada: dizer que sim esconderia um agendamento que continua de pe',
  );
});
