# ESP32 virtual (modo push)

Este documento explica como o simulador pode se comportar como o aparelho
ESP32 real, empurrando leituras por HTTP em vez de ser lido por dentro do
processo. O objetivo e testar a arquitetura hibrida com a mesma interface que o
hardware fisico usara, de modo que a troca do simulador pelo ESP32 real nao
exija mudanca de codigo no servidor.

## Os dois papeis

A arquitetura tem dois papeis que, para um teste fiel, devem rodar separados:

- **Aparelho (ESP32 / ESP32 virtual)** — tem a "verdade fisica", responde
  `GET /status`, `GET /` e `POST /sincronizar`. Roda **local**, na mesma rede
  Wi-Fi do celular. E o que garante o funcionamento em modo Edge (sem internet).
- **Servidor de nuvem** — guarda o historico (Supabase) e permite acesso
  remoto. Recebe as leituras via `POST /leitura`.

Por que o aparelho **empurra** e a nuvem nao **puxa**: um servidor na nuvem nao
alcanca o ESP32 dentro da rede da fazenda (NAT do roteador, sem IP publico).
Por isso o aparelho faz uma conexao de saida (`POST /leitura`).

```
   REDE LOCAL (Wi-Fi)                              INTERNET
┌───────────────────────────┐            ┌───────────────────────────┐
│  ESP32 virtual (local)     │            │  servidor de nuvem         │
│  GET /status, GET /        │            │  recebe POST /leitura      │
│  POST /sincronizar         │──POST /leitura──►│  grava no Supabase   │
│           ▲                │  (empurra) │  serve historico remoto    │
│           │ GET (LAN)      │            └───────────────────────────┘
│        App (celular)       │
└────────────────────────────┘
   funciona mesmo sem internet (Edge)
```

## Ligar o modo push

Configure no `.env` do processo que faz o papel de **aparelho**:

```bash
PUSH_TARGET_URL=https://sua-estufa.onrender.com   # URL do servidor de nuvem
PUSH_INTERVAL_MS=600000                            # intervalo entre envios (10 min)
PUSH_TOKEN=                                         # se vazio, usa ESTUFA_API_TOKEN
```

Quando `PUSH_TARGET_URL` esta vazio, o processo usa apenas o polling interno de
hoje (comportamento inalterado). Quando esta preenchido, ele passa a empurrar as
leituras do simulador para o servidor de nuvem.

Se o alvo estiver inacessivel (queda de internet), as leituras vao para um
buffer local (`.buffer_push.jsonl`) e sao reenviadas em ordem quando a conexao
volta — o mesmo comportamento que o ESP32 real precisaria ter no campo.

## Testar os dois papeis na mesma maquina

1. **Servidor de nuvem** (com banco), na porta 3000:

   ```powershell
   $env:PORT="3000"; node server.js
   ```

2. **Aparelho (ESP32 virtual)**, na porta 3001, empurrando para o de cima:

   ```powershell
   $env:PORT="3001"
   $env:PUSH_TARGET_URL="http://localhost:3000"
   $env:PUSH_INTERVAL_MS="5000"
   node server.js
   ```

O app aponta para o aparelho (`http://IP_DO_PC:3001`) para leitura local, e o
historico aparece no banco através do servidor de nuvem.

## Levar para a nuvem

O projeto ja tem `Dockerfile` e `docker-compose.yml`. Para hospedar o servidor
de nuvem em um plano gratuito (Render, Railway ou Fly.io), configure as
variaveis `DATABASE_URL` (Supabase) e `ESTUFA_API_TOKEN`, e faca o deploy da
pasta `estufa_server`. Depois aponte o `PUSH_TARGET_URL` do aparelho para a URL
publica gerada.

Importante: apenas o **servidor de nuvem** vai para a internet. O aparelho
(ESP32 virtual hoje, ESP32 real depois) continua na rede local, para preservar
a demonstracao de Edge Computing.
