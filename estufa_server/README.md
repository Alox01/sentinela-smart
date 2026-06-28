# Sentinela Smart Server

Servidor local da estufa usado pelo aplicativo Sentinela Smart. Ele expõe a API HTTP, roda o simulador e, quando configurado, salva dados em PostgreSQL/Supabase.

## Rodar sem Docker

```powershell
cd estufa_server
npm install
node server.js
```

Teste:

```text
http://localhost:3000/status
```

## Rodar com Docker

Na raiz do projeto:

```powershell
docker compose up --build
```

Teste:

```text
http://localhost:3000/status
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

## Observação para o TCC

O Docker padroniza o ambiente do servidor. Assim, a API pode ser executada da mesma forma em diferentes computadores, facilitando testes locais, demonstrações e futura implantação em nuvem ou em um servidor físico da propriedade.
