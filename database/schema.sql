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
