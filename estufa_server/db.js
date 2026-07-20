let Pool;

try {
  ({ Pool } = require('pg'));
} catch (_error) {
  Pool = null;
}

const connectionString = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL || '';

function criarConfigSsl(env = process.env) {
  if ((env.DB_SSL ?? '').trim().toLowerCase() === 'false') {
    return false;
  }

  const ca = (env.DB_SSL_CA ?? '').replace(/\\n/g, '\n').trim();
  if (ca) {
    return { rejectUnauthorized: true, ca };
  }

  // Sem CA nao da para validar a cadeia: o pooler do Supabase usa certificado
  // proprio, e exigir validacao aqui derrubava TODA a persistencia (testado:
  // "self-signed certificate in certificate chain"). A conexao segue cifrada;
  // para validar de verdade, baixe o CA do painel do Supabase (Settings >
  // Database > SSL) e cole o PEM em DB_SSL_CA.
  console.warn(
    'DB_SSL_CA nao configurado: conexao com o banco cifrada, mas sem validar ' +
      'o certificado. Configure DB_SSL_CA para validacao completa.',
  );
  return { rejectUnauthorized: false };
}

const pool = Pool && connectionString
  ? new Pool({
      connectionString,
      ssl: criarConfigSsl(),
    })
  : null;
const {
  criarRegistroLeitura,
  deveSalvarLeitura,
  statusParaLeituraPersistida,
} = require('./storage_policy');

const ultimasLeiturasSalvas = new Map();

const ID_SIMULADOR_PADRAO = 'ESP32_REALISTIC_V2';

function normalizarTipoDispositivo(status = {}) {
  const tipoInformado = status.tipoDispositivo || status.tipo_dispositivo;
  if (tipoInformado === 'hardware' || tipoInformado === 'simulador') {
    return tipoInformado;
  }

  return status.idHardware === ID_SIMULADOR_PADRAO || !status.idHardware
    ? 'simulador'
    : 'hardware';
}

function normalizarFonteLeitura(status = {}) {
  const fonteInformada = status.fonte;
  if (fonteInformada === 'hardware' || fonteInformada === 'simulador' || fonteInformada === 'manual') {
    return fonteInformada;
  }

  return normalizarTipoDispositivo(status);
}

function normalizarIpLocal(status = {}) {
  return status.ipLocal || status.ip || null;
}

function estaHabilitado() {
  return Boolean(pool);
}

function motivoDesabilitado() {
  if (!connectionString) return 'DATABASE_URL nao configurada.';
  if (!Pool) return 'Dependencia pg nao instalada. Execute npm install pg.';
  return null;
}

async function buscarOuCriarDispositivo(status) {
  const identificador = status.idHardware || ID_SIMULADOR_PADRAO;
  const tipoDispositivo = normalizarTipoDispositivo(status);
  const ipLocal = normalizarIpLocal(status);
  const nome = identificador === ID_SIMULADOR_PADRAO
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
      values ($1, $2, $3, $4, now())
      on conflict (identificador_hardware)
      do update set
        tipo_dispositivo = excluded.tipo_dispositivo,
        ip_local = coalesce(excluded.ip_local, dispositivos.ip_local),
        updated_at = now()
      returning id
    `,
    [nome, identificador, tipoDispositivo, ipLocal],
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
  const fonte = normalizarFonteLeitura(status);

  await pool.query(
    `
      insert into leituras (
        dispositivo_id,
        timestamp_origem_ms,
        temperatura,
        umidade,
        temperatura_meta,
        umidade_meta,
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
      values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
    `,
    [
      dispositivoId,
      status.timestampLeitura,
      status.temperaturaAtual,
      status.umidadeAtual,
      status.temperaturaMeta ?? null,
      status.umidadeMeta ?? null,
      status.alarmeAtivo ?? status.alertaIncendio ?? false,
      status.aviso || '',
      status.corStatus || 'green',
      status.faseAtual || '',
      status.temEnergia ?? null,
      status.temInternet ?? null,
      status.sinalWifi ?? null,
      status.aquecedorLigado,
      status.ventiladorLigado,
      status.umidificadorLigado,
      fonte,
    ],
  );
}

async function salvarSnapshot(dados) {
  if (!pool) return false;

  const { status, config } = dados;
  const agoraMs = Date.now();
  const chaveLeitura = status.idHardware || ID_SIMULADOR_PADRAO;
  const decisao = deveSalvarLeitura({
    ultimaLeitura: ultimasLeiturasSalvas.get(chaveLeitura),
    status,
    config,
    agoraMs,
  });

  if (!decisao.salvar) {
    return { salvo: false, motivo: decisao.motivo };
  }

  const dispositivo = await buscarOuCriarDispositivo(status);
  await salvarConfiguracao(dispositivo.id, config);

  const leituraPersistida = {
    ...statusParaLeituraPersistida(status),
    temperaturaMeta: config?.temperaturaMeta ?? status.temperaturaMeta ?? null,
    umidadeMeta: config?.umidadeMeta ?? status.umidadeMeta ?? null,
  };
  await salvarLeitura(dispositivo.id, leituraPersistida);
  ultimasLeiturasSalvas.set(chaveLeitura, criarRegistroLeitura(status, config, agoraMs));
  return { salvo: true, motivo: decisao.motivo };
}

// Insere uma leitura ja decidida (sem passar pela politica de deduplicacao),
// usada para reenviar leituras do buffer offline e para a ingestao direta do
// hardware via POST /leitura. A config e opcional porque o hardware pode
// enviar apenas a telemetria. Lanca se a nuvem estiver indisponivel, para que
// o chamador possa guardar a leitura no buffer.
async function persistirLeituraBufferizada(dados) {
  if (!pool) {
    throw new Error('Persistencia desabilitada: banco nao configurado.');
  }

  const { status, config } = dados;
  const dispositivo = await buscarOuCriarDispositivo(status);
  if (config) {
    await salvarConfiguracao(dispositivo.id, config);
  }

  const leituraPersistida = {
    ...statusParaLeituraPersistida(status),
    temperaturaMeta: status.temperaturaMeta ?? config?.temperaturaMeta ?? null,
    umidadeMeta: status.umidadeMeta ?? config?.umidadeMeta ?? null,
  };
  await salvarLeitura(dispositivo.id, leituraPersistida);
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
  const identificador = payload?.idHardware || config?.idHardware || ID_SIMULADOR_PADRAO;
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

// Lista as leituras persistidas de um dispositivo dentro de um periodo, para
// o relatorio remoto preencher o historico gravado enquanto o app estava
// fechado. Ordenado do mais antigo para o mais recente.
async function carregarHistorico(
  identificadorHardware = 'ESP32_REALISTIC_V2',
  { inicioMs, fimMs, limite = 5000 } = {},
) {
  if (!pool) return [];

  const condicoes = ['d.identificador_hardware = $1'];
  const parametros = [identificadorHardware];

  if (Number.isFinite(inicioMs)) {
    parametros.push(Math.round(inicioMs));
    condicoes.push(`l.timestamp_origem_ms >= $${parametros.length}`);
  }
  if (Number.isFinite(fimMs)) {
    parametros.push(Math.round(fimMs));
    condicoes.push(`l.timestamp_origem_ms <= $${parametros.length}`);
  }
  parametros.push(Math.min(Math.max(Number(limite) || 5000, 1), 20000));
  const limiteParam = `$${parametros.length}`;

  const result = await pool.query(
    `
      with historico_recente as (
        select
          l.timestamp_origem_ms,
          l.timestamp_leitura,
          l.temperatura,
          l.umidade,
          l.temperatura_meta,
          l.umidade_meta,
          l.alerta_incendio,
          l.aviso,
          l.cor_status,
          l.fonte
        from dispositivos d
        join leituras l on l.dispositivo_id = d.id
        where ${condicoes.join(' and ')}
        order by coalesce(
          l.timestamp_origem_ms,
          extract(epoch from l.timestamp_leitura) * 1000
        ) desc
        limit ${limiteParam}
      )
      select *
      from historico_recente
      order by coalesce(
        timestamp_origem_ms,
        extract(epoch from timestamp_leitura) * 1000
      ) asc
    `,
    parametros,
  );

  return result.rows.map((row) => ({
    timestampLeitura:
      Number(row.timestamp_origem_ms)
      || new Date(row.timestamp_leitura).getTime(),
    temperaturaAtual: Number(row.temperatura),
    umidadeAtual: Number(row.umidade),
    temperaturaMeta: row.temperatura_meta == null ? null : Number(row.temperatura_meta),
    umidadeMeta: row.umidade_meta == null ? null : Number(row.umidade_meta),
    alertaIncendio: row.alerta_incendio,
    aviso: row.aviso || '',
    corStatus: row.cor_status || 'green',
    fonte: row.fonte,
  }));
}

// Apaga leituras mais antigas que a janela de retencao. Espelha, na nuvem, a
// retencao que o Isar ja faz no celular: uma estufada dura ~10 dias, entao o
// historico util cabe com folga na janela. Sem isso o banco so cresce - foi o
// que levou a tabela a 2,7 milhoes de linhas e estourou a cota do Supabase.
async function apagarLeiturasAntigas(diasRetencao) {
  if (!pool) return { apagadas: 0 };
  const dias = Number(diasRetencao);
  if (!Number.isFinite(dias) || dias <= 0) return { apagadas: 0 };

  const result = await pool.query(
    `delete from leituras where timestamp_leitura < now() - ($1::int * interval '1 day')`,
    [Math.round(dias)],
  );
  return { apagadas: result.rowCount };
}

// ---- Aparelhos inscritos para push (token FCM por estufa) ----
// Um celular pode acompanhar varias estufas e uma estufa pode ter varios
// celulares, entao a chave e o par (token, idHardware).

let tabelaPushPronta = false;

async function garantirTabelaPush() {
  if (tabelaPushPronta) return;
  await pool.query(`
    create table if not exists push_dispositivos (
      token_push text not null,
      identificador_hardware text not null,
      plataforma text,
      preferencias jsonb,
      updated_at timestamptz not null default now(),
      primary key (token_push, identificador_hardware)
    )
  `);
  tabelaPushPronta = true;
}

async function registrarDispositivoPush({
  tokenPush,
  idHardware,
  plataforma,
  preferencias,
}) {
  if (!pool) return false;
  await garantirTabelaPush();
  await pool.query(
    `
      insert into push_dispositivos (
        token_push, identificador_hardware, plataforma, preferencias, updated_at
      )
      values ($1, $2, $3, $4, now())
      on conflict (token_push, identificador_hardware)
      do update set
        plataforma = excluded.plataforma,
        preferencias = excluded.preferencias,
        updated_at = now()
    `,
    [tokenPush, idHardware, plataforma ?? null, preferencias ?? null],
  );
  return true;
}

async function removerDispositivoPush({ tokenPush, idHardware }) {
  if (!pool) return false;
  await garantirTabelaPush();
  if (idHardware) {
    await pool.query(
      'delete from push_dispositivos where token_push = $1 and identificador_hardware = $2',
      [tokenPush, idHardware],
    );
  } else {
    await pool.query('delete from push_dispositivos where token_push = $1', [
      tokenPush,
    ]);
  }
  return true;
}

/// Tokens inscritos numa estufa, com as preferencias de quem os registrou -
/// e por elas que o envio decide suprimir um evento silenciado.
async function listarDispositivosPush(idHardware) {
  if (!pool) return [];
  await garantirTabelaPush();
  const result = await pool.query(
    'select token_push, preferencias from push_dispositivos where identificador_hardware = $1',
    [idHardware],
  );
  return result.rows.map((row) => ({
    tokenPush: row.token_push,
    preferencias: row.preferencias || null,
  }));
}

/// Aparelhos que tem alguem inscrito no push - so esses interessam ao watchdog:
/// vigiar o silencio de uma estufa que ninguem acompanha nao serve a ninguem.
async function listarAparelhosComPush() {
  if (!pool) return [];
  await garantirTabelaPush();
  const result = await pool.query(
    'select distinct identificador_hardware from push_dispositivos',
  );
  return result.rows.map((row) => row.identificador_hardware);
}

async function removerTokensPushInvalidos(tokens) {
  if (!pool || !tokens?.length) return 0;
  await garantirTabelaPush();
  const result = await pool.query(
    'delete from push_dispositivos where token_push = any($1::text[])',
    [tokens],
  );
  return result.rowCount;
}

// ---- Caixa de comandos pendentes (sobrevive a restarts do servidor) ----
// O plano gratuito do Render recicla o processo com frequencia; sem persistir,
// um ajuste feito de longe sumia em silencio se o dyno reiniciasse antes de o
// aparelho buscar. Uma linha por aparelho: o payload ja chega fundido por campo.

let tabelaComandosPendentesPronta = false;

async function garantirTabelaComandosPendentes() {
  if (tabelaComandosPendentesPronta) return;
  await pool.query(`
    create table if not exists comandos_pendentes (
      identificador_hardware text primary key,
      payload jsonb not null,
      updated_at timestamptz not null default now()
    )
  `);
  tabelaComandosPendentesPronta = true;
}

async function salvarComandoPendente(identificadorHardware, payload) {
  if (!pool) return false;
  await garantirTabelaComandosPendentes();
  await pool.query(
    `
      insert into comandos_pendentes (identificador_hardware, payload, updated_at)
      values ($1, $2, now())
      on conflict (identificador_hardware)
      do update set payload = excluded.payload, updated_at = now()
    `,
    [identificadorHardware, payload],
  );
  return true;
}

async function removerComandoPendente(identificadorHardware) {
  if (!pool) return false;
  await garantirTabelaComandosPendentes();
  await pool.query(
    'delete from comandos_pendentes where identificador_hardware = $1',
    [identificadorHardware],
  );
  return true;
}

async function carregarComandosPendentes() {
  if (!pool) return [];
  await garantirTabelaComandosPendentes();
  const result = await pool.query(
    'select identificador_hardware, payload from comandos_pendentes',
  );
  return result.rows.map((row) => ({
    idHardware: row.identificador_hardware,
    comando: row.payload,
  }));
}

module.exports = {
  apagarLeiturasAntigas,
  carregarComandosPendentes,
  carregarConfiguracao,
  listarAparelhosComPush,
  listarDispositivosPush,
  registrarDispositivoPush,
  removerDispositivoPush,
  removerTokensPushInvalidos,
  carregarHistorico,
  carregarUltimaLeitura,
  estaHabilitado,
  motivoDesabilitado,
  persistirLeituraBufferizada,
  removerComandoPendente,
  salvarComandoPendente,
  salvarComandoSync,
  salvarConfiguracaoSnapshot,
  salvarSnapshot,
  __testables: {
    criarConfigSsl,
    normalizarFonteLeitura,
    normalizarIpLocal,
    normalizarTipoDispositivo,
  },
};
