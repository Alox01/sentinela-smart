let Pool;

try {
  ({ Pool } = require('pg'));
} catch (_error) {
  Pool = null;
}

const connectionString = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL || '';
const pool = Pool && connectionString
  ? new Pool({
      connectionString,
      ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: false },
    })
  : null;

function estaHabilitado() {
  return Boolean(pool);
}

function motivoDesabilitado() {
  if (!connectionString) return 'DATABASE_URL nao configurada.';
  if (!Pool) return 'Dependencia pg nao instalada. Execute npm install pg.';
  return null;
}

async function buscarOuCriarDispositivo(status) {
  const identificador = status.idHardware || 'ESP32_REALISTIC_V2';
  const nome = identificador === 'ESP32_REALISTIC_V2'
    ? 'Estufa Simulada'
    : `Dispositivo ${identificador}`;

  const result = await pool.query(
    `
      insert into dispositivos (
        nome,
        identificador_hardware,
        tipo_dispositivo,
        ip_local,
        updated_at
      )
      values ($1, $2, 'simulador', 'localhost', now())
      on conflict (identificador_hardware)
      do update set updated_at = now()
      returning id
    `,
    [nome, identificador],
  );

  return {
    id: result.rows[0].id,
    identificador,
  };
}

async function salvarConfiguracao(dispositivoId, config) {
  await pool.query(
    `
      insert into configuracoes (
        dispositivo_id,
        temperatura_meta,
        temp_timestamp,
        umidade_meta,
        umid_timestamp,
        modo_silencioso,
        modo_silencioso_timestamp,
        updated_at
      )
      values ($1, $2, $3, $4, $5, $6, $7, now())
      on conflict (dispositivo_id)
      do update set
        temperatura_meta = excluded.temperatura_meta,
        temp_timestamp = excluded.temp_timestamp,
        umidade_meta = excluded.umidade_meta,
        umid_timestamp = excluded.umid_timestamp,
        modo_silencioso = excluded.modo_silencioso,
        modo_silencioso_timestamp = excluded.modo_silencioso_timestamp,
        updated_at = now()
    `,
    [
      dispositivoId,
      config.temperaturaMeta,
      config.tempTimestamp,
      config.umidadeMeta,
      config.umidTimestamp,
      config.modoSilencioso,
      config.modoSilenciosoTimestamp,
    ],
  );
}

async function salvarLeitura(dispositivoId, status) {
  await pool.query(
    `
      insert into leituras (
        dispositivo_id,
        timestamp_origem_ms,
        temperatura,
        umidade,
        alerta_incendio,
        aviso,
        cor_status,
        fase_atual,
        tem_energia,
        tem_internet,
        sinal_wifi,
        aquecedor_ligado,
        ventilador_ligado,
        umidificador_ligado,
        fonte
      )
      values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'simulador')
    `,
    [
      dispositivoId,
      status.timestampLeitura,
      status.temperaturaAtual,
      status.umidadeAtual,
      status.alarmeAtivo ?? status.alertaIncendio,
      status.aviso || '',
      status.corStatus || 'green',
      status.faseAtual || '',
      status.temEnergia,
      status.temInternet,
      status.sinalWifi,
      status.aquecedorLigado,
      status.ventiladorLigado,
      status.umidificadorLigado,
    ],
  );
}

async function salvarSnapshot(dados) {
  if (!pool) return false;

  const { status, config } = dados;
  const dispositivo = await buscarOuCriarDispositivo(status);
  await salvarConfiguracao(dispositivo.id, config);
  await salvarLeitura(dispositivo.id, status);
  return true;
}

async function salvarConfiguracaoSnapshot(dados) {
  if (!pool) return false;

  const { status, config } = dados;
  const dispositivo = await buscarOuCriarDispositivo(status);
  await salvarConfiguracao(dispositivo.id, config);
  return true;
}

async function salvarComandoSync(payload, resultado, status = 'aplicado') {
  if (!pool) return false;

  const config = resultado?.configAtualizada;
  const identificador = config?.idHardware || 'ESP32_REALISTIC_V2';
  const dispositivoResult = await pool.query(
    'select id from dispositivos where identificador_hardware = $1 limit 1',
    [identificador],
  );
  const dispositivoId = dispositivoResult.rows[0]?.id ?? null;

  await pool.query(
    `
      insert into comandos_sync (
        dispositivo_id,
        identificador_hardware,
        payload,
        status,
        origem,
        synced_at
      )
      values ($1, $2, $3, $4, 'app', now())
    `,
    [dispositivoId, identificador, payload, status],
  );

  if (dispositivoId && config) {
    await salvarConfiguracao(dispositivoId, config);
  }

  return true;
}

async function carregarConfiguracao(identificadorHardware = 'ESP32_REALISTIC_V2') {
  if (!pool) return null;

  const result = await pool.query(
    `
      select
        d.identificador_hardware,
        c.temperatura_meta,
        c.temp_timestamp,
        c.umidade_meta,
        c.umid_timestamp,
        c.modo_silencioso,
        c.modo_silencioso_timestamp
      from dispositivos d
      join configuracoes c on c.dispositivo_id = d.id
      where d.identificador_hardware = $1
      limit 1
    `,
    [identificadorHardware],
  );

  const row = result.rows[0];
  if (!row) return null;

  return {
    idHardware: row.identificador_hardware,
    temperaturaMeta: Number(row.temperatura_meta),
    tempTimestamp: Number(row.temp_timestamp),
    umidadeMeta: Number(row.umidade_meta),
    umidTimestamp: Number(row.umid_timestamp),
    modoSilencioso: row.modo_silencioso,
    modoSilenciosoTimestamp: Number(row.modo_silencioso_timestamp),
  };
}

async function carregarUltimaLeitura(identificadorHardware = 'ESP32_REALISTIC_V2') {
  if (!pool) return null;

  const result = await pool.query(
    `
      select
        d.identificador_hardware,
        l.timestamp_origem_ms,
        l.temperatura,
        l.umidade,
        l.alerta_incendio,
        l.aviso,
        l.cor_status,
        l.fase_atual,
        l.tem_energia,
        l.tem_internet,
        l.sinal_wifi,
        l.aquecedor_ligado,
        l.ventilador_ligado,
        l.umidificador_ligado
      from dispositivos d
      join leituras l on l.dispositivo_id = d.id
      where d.identificador_hardware = $1
      order by l.timestamp_leitura desc
      limit 1
    `,
    [identificadorHardware],
  );

  const row = result.rows[0];
  if (!row) return null;

  return {
    idHardware: row.identificador_hardware,
    timestampLeitura: Number(row.timestamp_origem_ms) || Date.now(),
    temperaturaAtual: Number(row.temperatura),
    umidadeAtual: Number(row.umidade),
    alarmeAtivo: row.alerta_incendio,
    perigoChama: false,
    riscoIncendio: false,
    alertaIncendio: row.alerta_incendio,
    aviso: row.aviso || '',
    corStatus: row.cor_status || 'green',
    faseAtual: row.fase_atual || '',
    temEnergia: row.tem_energia,
    temInternet: row.tem_internet,
    sinalWifi: row.sinal_wifi,
    aquecedorLigado: row.aquecedor_ligado,
    ventiladorLigado: row.ventilador_ligado,
    umidificadorLigado: row.umidificador_ligado,
  };
}

module.exports = {
  carregarConfiguracao,
  carregarUltimaLeitura,
  estaHabilitado,
  motivoDesabilitado,
  salvarComandoSync,
  salvarConfiguracaoSnapshot,
  salvarSnapshot,
};
