# Sentinela Smart Server

Servidor local da estufa usado pelo aplicativo Sentinela Smart. Ele expõe a API HTTP, roda o simulador e, quando configurado, salva dados em PostgreSQL/Supabase.

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

Com restrição de origem para o app web:

```powershell
$env:ALLOWED_ORIGINS="http://192.168.1.11:53312,http://localhost:53312"
docker compose up --build
```


## Segurança da API

Quando `ESTUFA_API_TOKEN` está configurada, as rotas que alteram o equipamento exigem a mesma chave de acesso enviada pelo app:

- `POST /sincronizar`, usado para alterar ajustes de temperatura, umidade e modo silencioso;
- `POST /debug/botao-fisico`, usado apenas para simular alteração física durante testes.

As leituras `GET /status`, `GET /` e `GET /dados` continuam publicas na rede local para facilitar monitoramento e diagnostico. A rota `/status` entrega o formato completo do simulador; `/` e `/dados` entregam um JSON simples compativel com o ESP32. Os comandos tambem passam por validacao de payload: temperatura aceita de 60 F a 200 F e umidade aceita de 0% a 100%.

A variável `ALLOWED_ORIGINS` é opcional. Sem ela, o CORS fica liberado para facilitar testes locais. Com ela configurada, navegadores só conseguem chamar a API a partir das origens listadas.

## Observação para o TCC

O Docker padroniza o ambiente do servidor. Assim, a API pode ser executada da mesma forma em diferentes computadores, facilitando testes locais, demonstrações e futura implantação em nuvem ou em um servidor físico da propriedade.
