# Sentinela Smart Server

Servidor local da estufa usado pelo aplicativo Sentinela Smart. Ele expõe a API HTTP, roda o simulador e, quando configurado, salva dados em PostgreSQL/Supabase.

## Rodar sem Docker

```powershell
cd estufa_server
npm install
npm start
```

Teste no navegador:

```text
http://localhost:3000/status
http://localhost:3000/dados
```

## Rodar com Docker

Na raiz do projeto:

```powershell
docker compose up --build
```

Teste no navegador:

```text
http://localhost:3000/status
http://localhost:3000/dados
```

## Variáveis opcionais

Sem variáveis, o servidor roda em modo simulação e sem autenticação.

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

Com banco e intervalo de persistência personalizado:

```powershell
$env:DATABASE_URL="postgresql://usuario:senha@host:5432/postgres"
$env:PERSIST_READINGS_INTERVAL_MS="600000"
docker compose up --build
```

`PERSIST_READINGS_INTERVAL_MS` é opcional. O padrão é `600000` ms, ou seja, 10 minutos. Mesmo com esse intervalo, o servidor só grava uma nova leitura quando ela é útil para o relatório: primeira leitura, mudança de ajuste, mudança de alarme, desvio relevante ou passagem do intervalo definido.

Com restrição de origem para o app web:

```powershell
$env:ALLOWED_ORIGINS="http://192.168.1.11:53312,http://localhost:53312"
docker compose up --build
```

## Endpoints principais

- `GET /status`: formato completo usado pelo simulador e pelo servidor local.
- `GET /` e `GET /dados`: formato simples compatível com o protótipo ESP32, incluindo `umidadeAlvo` no simulador para aproximar o teste do contrato final.
- `POST /sincronizar`: recebe comandos de ajuste enviados pelo aplicativo.
- `POST /debug/botao-fisico`: usado apenas em testes para simular comando físico.

O app primeiro tenta ler `/status`. Se esse endpoint não existir, ele tenta o JSON simples na raiz (`/`), que foi o formato usado no ESP32 do protótipo.

## Segurança da API

Quando `ESTUFA_API_TOKEN` está configurada, as rotas que alteram o equipamento exigem a mesma chave de acesso enviada pelo app:

- `POST /sincronizar`, usado para alterar ajustes de temperatura, umidade e modo silencioso;
- `POST /debug/botao-fisico`, usado apenas para simular alteração física durante testes.

As leituras `GET /status`, `GET /` e `GET /dados` continuam públicas na rede local para facilitar monitoramento e diagnóstico. Os comandos também passam por validação de payload: temperatura aceita de 60°F a 200°F e umidade aceita de 0% a 100%.

A variável `ALLOWED_ORIGINS` é opcional. Sem ela, o CORS fica liberado para facilitar testes locais. Com ela configurada, navegadores só conseguem chamar a API a partir das origens listadas.

## Observação para o TCC

O Docker padroniza o ambiente do servidor. Assim, a API pode ser executada da mesma forma em diferentes computadores, facilitando testes locais, demonstrações e futura implantação em nuvem ou em um servidor físico da propriedade.