const { carregarEnvLocal } = require('./env');

carregarEnvLocal();

const path = require('path');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { rateLimit } = require('express-rate-limit');

const simulador = require('./simulador');
const db = require('./db');
const { createAuthMiddleware } = require('./auth');
const { avaliarTokenApi } = require('./token_policy');
const { createEstufaRouter } = require('./routes/estufa_routes');
const { createCorsOptions } = require('./security');
const { criarBufferLeituras } = require('./leitura_buffer');
const { iniciarPushLeituras } = require('./esp32_virtual');
const { iniciarKeepAlive } = require('./keep_alive');
const {
  iniciarPersistenciaPeriodica,
  lerIntervaloPersistencia,
} = require('./persistence_scheduler');
const { iniciarRetencao, lerDiasRetencao } = require('./retention_scheduler');
const { criarEnviadorPush } = require('./push');

const app = express();
const API_TOKEN = process.env.ESTUFA_API_TOKEN ?? process.env.API_AUTH_TOKEN ?? '';

// Exige um token forte para subir. Sem isso a API ficaria aberta a qualquer um
// que alcance o servidor. Para desenvolvimento local sem token, defina
// explicitamente PERMITIR_SEM_TOKEN=true.
const PERMITIR_SEM_TOKEN =
  (process.env.PERMITIR_SEM_TOKEN ?? '').trim().toLowerCase() === 'true';
const politicaToken = avaliarTokenApi(API_TOKEN);
if (!politicaToken.ok) {
  if (PERMITIR_SEM_TOKEN) {
    console.warn(
      `ATENCAO: ${politicaToken.motivo}. Servidor subindo SEM protecao de ` +
        'token (PERMITIR_SEM_TOKEN=true). Use apenas em desenvolvimento local.',
    );
  } else {
    console.error(
      `ERRO: ${politicaToken.motivo}. Configure ESTUFA_API_TOKEN com um token ` +
        'forte (>= 8 caracteres, nao trivial) antes de iniciar o servidor.',
    );
    console.error(
      'Para desenvolvimento local sem token, defina PERMITIR_SEM_TOKEN=true.',
    );
    process.exit(1);
  }
}
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS ?? '';
const PORT = Number(process.env.PORT) || 3000;
const PERSIST_READINGS_INTERVAL_MS = lerIntervaloPersistencia(
  process.env.PERSIST_READINGS_INTERVAL_MS,
);
// Modo "ESP32 virtual": quando PUSH_TARGET_URL esta configurado, este processo
// deixa de depender do polling interno e passa a empurrar leituras por HTTP
// para o servidor de nuvem, como o aparelho fisico fara.
const PUSH_TARGET_URL = (process.env.PUSH_TARGET_URL ?? '').trim();
// URL publica deste servidor para o auto-ping que evita a hibernacao do plano
// gratuito. No Render, RENDER_EXTERNAL_URL ja vem preenchida automaticamente.
const KEEP_ALIVE_URL = (
  process.env.KEEP_ALIVE_URL ?? process.env.RENDER_EXTERNAL_URL ?? ''
).trim();
const PUSH_TOKEN = process.env.PUSH_TOKEN ?? API_TOKEN;
const PUSH_INTERVAL_MS = lerIntervaloPersistencia(process.env.PUSH_INTERVAL_MS);
// Retencao na nuvem: apaga leituras alem da janela (padrao ~10 meses), a
// contrapartida da retencao que o app ja faz local. Evita o banco crescer
// para sempre.
const RETENCAO_DIAS = lerDiasRetencao(process.env.CLOUD_RETENTION_DAYS);
// Persistencia local (agendador que grava direto no banco). Por padrao fica
// ligada quando ha banco, MAS desliga sozinha em modo aparelho (push ligado),
// para nao gravar duplicado ja que a nuvem persiste o que recebe. Pode ser
// forcada com PERSISTIR_LOCAL=true/false.
const PERSISTIR_LOCAL = process.env.PERSISTIR_LOCAL != null
  ? process.env.PERSISTIR_LOCAL.trim().toLowerCase() !== 'false'
  : !PUSH_TARGET_URL;
const authMiddleware = createAuthMiddleware(API_TOKEN);
// Se a credencial do Firebase nao estiver configurada, o push fica desabilitado
// e o servidor sobe igual: aviso remoto e camada extra, nao caminho critico.
const enviadorPush = criarEnviadorPush();
const bufferLeituras = criarBufferLeituras(
  process.env.LEITURA_BUFFER_PATH ? { caminho: process.env.LEITURA_BUFFER_PATH } : {},
);
const bufferPush = criarBufferLeituras({
  caminho: process.env.PUSH_BUFFER_PATH || path.join(__dirname, '.buffer_push.jsonl'),
});

app.disable('x-powered-by');
app.use(
  helmet({
    // A API local pode ser consumida pelo app servido em outra origem.
    crossOriginResourcePolicy: false,
  }),
);
app.use(
  rateLimit({
    windowMs: 60_000,
    limit: 180,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: { sucesso: false, erro: 'Muitas requisicoes. Tente novamente em instantes.' },
  }),
);
app.use(express.json({ limit: '64kb' }));
app.use(cors(createCorsOptions(ALLOWED_ORIGINS)));
app.use(
  createEstufaRouter({
    simulador,
    db,
    authMiddleware,
    tokenConfigurado: Boolean(API_TOKEN.trim()),
    buffer: bufferLeituras,
    push: enviadorPush,
  }),
);

console.log('>>> SERVIDOR DE ESTUFA INICIADO (MODO SIMULACAO) <<<');
if (API_TOKEN.trim()) {
  console.log('Autenticacao habilitada por token.');
} else {
  console.log('Autenticacao desabilitada (token nao configurado).');
}
if (ALLOWED_ORIGINS.trim()) {
  console.log(`CORS restrito para: ${ALLOWED_ORIGINS}`);
} else {
  console.log('CORS liberado para desenvolvimento local.');
}
if (db.estaHabilitado()) {
  console.log('Banco PostgreSQL conectado.');
  if (PERSISTIR_LOCAL) {
    console.log(
      `Persistencia local ligada: leituras periodicas a cada ${Math.round(
        PERSIST_READINGS_INTERVAL_MS / 1000,
      )}s.`,
    );
  } else {
    console.log('Persistencia local desligada (modo aparelho): a nuvem grava via /leitura.');
  }
} else {
  console.log(`Persistencia PostgreSQL desabilitada: ${db.motivoDesabilitado()}`);
}
if (PUSH_TARGET_URL) {
  console.log(
    `ESP32 virtual: empurrando leituras para ${PUSH_TARGET_URL} a cada ${Math.round(
      PUSH_INTERVAL_MS / 1000,
    )}s.`,
  );
} else {
  console.log('ESP32 virtual (push HTTP) desabilitado: PUSH_TARGET_URL nao configurada.');
}

async function iniciarServidor() {
  if (db.estaHabilitado()) {
    try {
      const configPersistida = await db.carregarConfiguracao();
      simulador.aplicarConfiguracaoPersistida(configPersistida);

      const statusPersistido = await db.carregarUltimaLeitura();
      simulador.aplicarStatusPersistido(statusPersistido);
    } catch (error) {
      console.error('Falha ao carregar estado persistido:', error.message);
    }
  }

  app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}!`);
    console.log(`Teste de leitura: GET http://localhost:${PORT}/status`);
  });

  if (PERSISTIR_LOCAL) {
    iniciarPersistenciaPeriodica({
      db,
      simulador,
      intervaloMs: PERSIST_READINGS_INTERVAL_MS,
      buffer: bufferLeituras,
    });
  }

  iniciarRetencao({ db, diasRetencao: RETENCAO_DIAS });
  if (db.estaHabilitado()) {
    console.log(`Retencao de leituras: janela de ${RETENCAO_DIAS} dias.`);
  }

  if (PUSH_TARGET_URL) {
    iniciarPushLeituras({
      lerStatus: () => {
        const { status, config } = simulador.lerCompleto();
        // Empurra o ajuste vigente junto da leitura para a nuvem registrar o
        // setpoint por ponto (linha de meta e cores no relatorio).
        return {
          ...status,
          temperaturaMeta: config.temperaturaMeta,
          umidadeMeta: config.umidadeMeta,
        };
      },
      alvoUrl: PUSH_TARGET_URL,
      token: PUSH_TOKEN,
      intervaloMs: PUSH_INTERVAL_MS,
      buffer: bufferPush,
    });
  }

  if (KEEP_ALIVE_URL) {
    iniciarKeepAlive({ url: KEEP_ALIVE_URL });
    console.log(`Keep-alive ativo para ${KEEP_ALIVE_URL}.`);
  }
}

iniciarServidor();
