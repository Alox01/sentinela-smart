-- Schema inicial para PostgreSQL/Supabase.
-- Objetivo: persistir dados do simulador e, futuramente, do hardware real
-- sem precisar criar bancos separados.

create extension if not exists "pgcrypto";

create table if not exists dispositivos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  identificador_hardware text not null unique,
  tipo_dispositivo text not null default 'simulador',
  ip_local text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint dispositivos_tipo_check
    check (tipo_dispositivo in ('simulador', 'hardware'))
);

create table if not exists configuracoes (
  dispositivo_id uuid primary key references dispositivos(id) on delete cascade,
  temperatura_meta numeric(6,2) not null default 90.00,
  temp_timestamp bigint not null default 0,
  umidade_meta numeric(5,2) not null default 99.00,
  umid_timestamp bigint not null default 0,
  modo_silencioso boolean not null default false,
  modo_silencioso_timestamp bigint not null default 0,
  updated_at timestamptz not null default now(),

  constraint configuracoes_temperatura_check
    check (temperatura_meta >= 0 and temperatura_meta <= 999),
  constraint configuracoes_umidade_check
    check (umidade_meta >= 0 and umidade_meta <= 100),
  constraint configuracoes_timestamps_check
    check (
      temp_timestamp >= 0
      and umid_timestamp >= 0
      and modo_silencioso_timestamp >= 0
    )
);

create table if not exists leituras (
  id bigserial primary key,
  dispositivo_id uuid not null references dispositivos(id) on delete cascade,
  timestamp_leitura timestamptz not null default now(),
  timestamp_origem_ms bigint,
  temperatura numeric(6,2) not null,
  umidade numeric(5,2) not null,
  -- Ajuste (setpoint) vigente no momento da leitura, para o relatorio remoto
  -- reconstruir a linha de meta e as cores por ponto.
  temperatura_meta numeric(6,2),
  umidade_meta numeric(5,2),
  alerta_incendio boolean not null default false,
  aviso text not null default '',
  cor_status text not null default 'green',
  fase_atual text not null default '',
  tem_energia boolean,
  tem_internet boolean,
  sinal_wifi integer,
  aquecedor_ligado boolean,
  ventilador_ligado boolean,
  umidificador_ligado boolean,
  fonte text not null default 'simulador',
  created_at timestamptz not null default now(),

  constraint leituras_temperatura_check
    check (temperatura >= -100 and temperatura <= 999),
  constraint leituras_umidade_check
    check (umidade >= 0 and umidade <= 100),
  constraint leituras_sinal_wifi_check
    check (sinal_wifi is null or (sinal_wifi >= 0 and sinal_wifi <= 100)),
  constraint leituras_fonte_check
    check (fonte in ('simulador', 'hardware', 'manual'))
);

create table if not exists comandos_sync (
  id bigserial primary key,
  dispositivo_id uuid references dispositivos(id) on delete set null,
  identificador_hardware text,
  payload jsonb not null,
  status text not null default 'pendente',
  origem text not null default 'app',
  erro text,
  created_at timestamptz not null default now(),
  synced_at timestamptz,

  constraint comandos_sync_status_check
    check (status in ('pendente', 'enviado', 'aplicado', 'ignorado', 'erro')),
  constraint comandos_sync_origem_check
    check (origem in ('app', 'hardware', 'simulador', 'admin'))
);

-- ============================================================
-- Tabelas criadas em tempo de execucao pelo servidor
-- ============================================================
-- Nasceram depois deste arquivo, em `estufa_server/db.js`, cada uma com o seu
-- `create table if not exists` na primeira vez que a funcionalidade e usada.
-- Ficam declaradas aqui tambem para este arquivo descrever o banco INTEIRO —
-- foi por nao estarem que elas escaparam da revisao de RLS (ver o fim do
-- arquivo). O `if not exists` mantem tudo idempotente.

-- Tokens de push por aparelho, com as preferencias de aviso daquele celular.
create table if not exists push_dispositivos (
  token_push text not null,
  identificador_hardware text not null,
  plataforma text,
  preferencias jsonb,
  nome text,
  updated_at timestamptz not null default now(),
  primary key (token_push, identificador_hardware)
);

-- Caixa de comando pendente, um por aparelho: o ultimo comando vence o
-- anterior, e o aparelho o consome na proxima busca.
create table if not exists comandos_pendentes (
  identificador_hardware text primary key,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

-- Ajustes marcados para uma hora futura.
create table if not exists comandos_agendados (
  id bigserial primary key,
  identificador_hardware text not null,
  aplicar_em_ms bigint not null,
  payload jsonb not null,
  criado_em timestamptz not null default now()
);

-- O agendador varre por vencimento a cada 30 s; sem indice isso seria uma
-- varredura completa da tabela toda vez.
create index if not exists comandos_agendados_aplicar_em_ms_idx
  on comandos_agendados (aplicar_em_ms);

create index if not exists idx_leituras_dispositivo_timestamp
  on leituras (dispositivo_id, timestamp_leitura desc);

create index if not exists idx_leituras_fonte
  on leituras (fonte);

create index if not exists idx_comandos_sync_dispositivo_status
  on comandos_sync (dispositivo_id, status, created_at);

create index if not exists idx_comandos_sync_identificador_status
  on comandos_sync (identificador_hardware, status, created_at);

-- Registro inicial para o simulador atual.
insert into dispositivos (
  nome,
  identificador_hardware,
  tipo_dispositivo,
  ip_local
)
values (
  'Estufa Simulada',
  'ESP32_REALISTIC_V2',
  'simulador',
  'localhost'
)
on conflict (identificador_hardware) do nothing;

insert into configuracoes (
  dispositivo_id,
  temperatura_meta,
  temp_timestamp,
  umidade_meta,
  umid_timestamp,
  modo_silencioso,
  modo_silencioso_timestamp
)
select
  id,
  90.00,
  0,
  99.00,
  0,
  false,
  0
from dispositivos
where identificador_hardware = 'ESP32_REALISTIC_V2'
on conflict (dispositivo_id) do nothing;

-- ============================================================
-- Row Level Security
-- ============================================================
-- O Supabase publica o schema `public` por uma API REST que aceita a chave
-- `anon`. Sem RLS, quem tiver essa chave le e ESCREVE nestas tabelas **por fora
-- do servidor** — e portanto por fora de toda a autenticacao do projeto.
--
-- O que doi nao e o cadastro de push: e `comandos_pendentes` e
-- `comandos_agendados`, que sao a caixa de comandos que o aparelho busca e
-- obedece. Escrever ali seria comandar a estufa sem chave, sem PIN e sem estar
-- na frente do aparelho — furando a regra central do trabalho.
--
-- **Sem politica nenhuma, de proposito.** Ligar RLS e nao criar policy fecha a
-- API REST por completo, e o servidor nao sente: ele conecta como `postgres`
-- pelo pooler, e o superusuario ignora RLS. Politica so faria sentido se um dia
-- o app falasse direto com o Supabase, o que hoje nao acontece.
--
-- Descoberto em 21/08/2026 pelo Advisor do Supabase, apontando as tres tabelas
-- criadas em tempo de execucao. As quatro deste arquivo ja estavam protegidas.

alter table dispositivos        enable row level security;
alter table configuracoes       enable row level security;
alter table leituras            enable row level security;
alter table comandos_sync       enable row level security;
alter table push_dispositivos   enable row level security;
alter table comandos_pendentes  enable row level security;
alter table comandos_agendados  enable row level security;

-- Conferencia: tudo tem de voltar com `rowsecurity = true`.
--   select tablename, rowsecurity
--   from pg_tables
--   where schemaname = 'public'
--   order by rowsecurity, tablename;
