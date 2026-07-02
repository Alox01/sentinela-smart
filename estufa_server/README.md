# Sentinela Smart Server

Servidor local da estufa usado pelo aplicativo Sentinela Smart. Ele expÃµe a API HTTP, roda o simulador e, quando configurado, salva dados em PostgreSQL/Supabase.

## Rodar sem Docker

```powershell
cd estufa_server
npm install
npm start
```

Teste:

```text
http://localhost:3000/status
http://localhost:3000/dados
```

## Rodar com Docker

Na raiz do projeto:

```powershell
docker compose up --build
```

Teste:

```text
http://localhost:3000/status
http://localhost:3000/dados
```

## VariÃ¡veis opcionais

Sem variÃ¡veis, o servidor roda em modo simulaÃ§Ã£o e sem autenticaÃ§Ã£o.

Com chave de acesso:

```powershell
$env:ESTUFA_API_TOKEN="minha-chave"
docker compose up --build
```

Com banco:

```powershell
$env:DATABASE_URL="postgresql://usuario:senha@host:5432/postgres"
docker compose up --build
```

Com banco e intervalo de persistÃªncia personalizado:

```powershell
$env:DATABASE_URL="postgresql://usuario:senha@host:5432/postgres"
$env:PERSIST_READINGS_INTERVAL_MS="600000"
docker compose up --build
```

`PERSIST_READINGS_INTERVAL_MS` Ã© opcional. O padrÃ£o Ã© `600000` ms, ou seja, 10 minutos. Mesmo com esse intervalo, o servidor sÃ³ grava uma nova leitura quando ela Ã© Ãºtil para o relatÃ³rio: primeira leitura, mudanÃ§a de ajuste, mudanÃ§a de alarme, desvio relevante ou passagem do intervalo definido.

Com restriÃ§Ã£o de origem para o app web:

```powershell
$env:ALLOWED_ORIGINS="http://192.168.1.11:53312,http://localhost:53312"
docker compose up --build
```

## SeguranÃ§a da API

Quando `ESTUFA_API_TOKEN` estÃ¡ configurada, as rotas que alteram o equipamento exigem a mesma chave de acesso enviada pelo app:

- `POST /sincronizar`, usado para alterar ajustes de temperatura, umidade e modo silencioso;
- `POST /debug/botao-fisico`, usado apenas para simular alteraÃ§Ã£o fÃ­sica durante testes.

As leituras `GET /status`, `GET /` e `GET /dados` continuam pÃºblicas na rede local para facilitar monitoramento e diagnÃ³stico. A rota `/status` entrega o formato completo do simulador; `/` e `/dados` entregam um JSON simples compatÃ­vel com o ESP32. Os comandos tambÃ©m passam por validaÃ§Ã£o de payload: temperatura aceita de 60 F a 200 F e umidade aceita de 0% a 100%.

A variÃ¡vel `ALLOWED_ORIGINS` Ã© opcional. Sem ela, o CORS fica liberado para facilitar testes locais. Com ela configurada, navegadores sÃ³ conseguem chamar a API a partir das origens listadas.

## ObservaÃ§Ã£o para o TCC

O Docker padroniza o ambiente do servidor. Assim, a API pode ser executada da mesma forma em diferentes computadores, facilitando testes locais, demonstraÃ§Ãµes e futura implantaÃ§Ã£o em nuvem ou em um servidor fÃ­sico da propriedade.
