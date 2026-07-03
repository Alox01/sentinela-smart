const { carregarEnvLocal } = require('./env');

carregarEnvLocal();

const express = require('express');
const cors = require('cors');

const simulador = require('./simulador');
const db = require('./db');
const { createAuthMiddleware } = require('./auth');
const { createEstufaRouter } = require('./routes/estufa_routes');
const { createCorsOptions } = require('./security');
const { criarBufferLeituras } = require('./leitura_buffer');
const {
  iniciarPersistenciaPeriodica,
  lerIntervaloPersistencia,
} = require('./persistence_scheduler');

const app = express();
const API_TOKEN = process.env.ESTUFA_API_TOKEN ?? process.env.API_AUTH_TOKEN ?? '';
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS ?? '';
const PORT = Number(process.env.PORT) || 3000;
const PERSIST_READINGS_INTERVAL_MS = lerIntervaloPersistencia(
  process.env.PERSIST_READINGS_INTERVAL_MS,
);
const authMiddleware = createAuthMiddleware(API_TOKEN);
const bufferLeituras = criarBufferLeituras(
  process.env.LEITURA_BUFFER_PATH ? { caminho: process.env.LEITURA_BUFFER_PATH } : {},
);

app.use(express.json());
app.use(cors(createCorsOptions(ALLOWED_ORIGINS)));
app.use(
  createEstufaRouter({
    simulador,
    db,
    authMiddleware,
    tokenConfigurado: Boolean(API_TOKEN.trim()),
    buffer: bufferLeituras,
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
  console.log('Persistencia PostgreSQL habilitada.');
  console.log(
    `Leituras periodicas a cada ${Math.round(PERSIST_READINGS_INTERVAL_MS / 1000)}s.`,
  );
} else {
  console.log(`Persistencia PostgreSQL desabilitada: ${db.motivoDesabilitado()}`);
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

  iniciarPersistenciaPeriodica({
    db,
    simulador,
    intervaloMs: PERSIST_READINGS_INTERVAL_MS,
    buffer: bufferLeituras,
  });
}

iniciarServidor();
