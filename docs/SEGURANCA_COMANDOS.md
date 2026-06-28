# Seguranca dos comandos da estufa

Esta camada protege os comandos que alteram o funcionamento da estufa, como
mudanca de meta de temperatura, mudanca de meta de umidade e silenciamento de
alarme.

## Regra atual

- `GET /status` continua liberado para leitura do estado da estufa.
- `POST /sincronizar` exige token quando o servidor estiver configurado com
  `ESTUFA_API_TOKEN`.
- `POST /debug/botao-fisico` tambem exige token quando configurado.

Se `ESTUFA_API_TOKEN` nao estiver configurado, o servidor roda em modo de
desenvolvimento e nao bloqueia os comandos. Isso facilita os testes locais com
o simulador.

No aplicativo, a chave pode ser configurada no cadastro/edicao da estufa. Assim
cada aparelho pode ter uma chave propria. Se a chave da estufa ficar vazia, o
app usa o token global informado por `--dart-define=ESTUFA_API_TOKEN=...`, caso
ele exista.

## Como o token e enviado

O aplicativo envia o token nos cabecalhos:

```http
Authorization: Bearer <token>
X-Device-Token: <token>
```

O servidor aceita os dois formatos. O cabecalho `X-Device-Token` foi mantido
para facilitar a futura integracao com o ESP32.

## Como testar localmente

No servidor:

```powershell
$env:ESTUFA_API_TOKEN="minha-chave-de-teste"
node server.js
```

Tambem existe o arquivo `estufa_server/.env.example` como modelo das variaveis
necessarias. O arquivo `.env` real deve ficar somente no computador de teste ou
no ambiente do servidor. Ao iniciar com `node server.js`, o servidor carrega
automaticamente `estufa_server/.env` quando esse arquivo existir.

No aplicativo Flutter:

```powershell
flutter run -d chrome --dart-define=ESTUFA_API_TOKEN=minha-chave-de-teste
```

Ou cadastre a estufa no app e preencha o campo
`Chave de acesso do aparelho` com a mesma chave usada no servidor/ESP32.

Se o token do aplicativo estiver diferente do token do servidor, os comandos de
controle retornam `401 Nao autorizado`.

## Limite desta camada

Esta medida evita que uma pessoa envie comandos simples para a estufa sem
conhecer a chave. Ela nao substitui HTTPS, controle de usuarios, revogacao de
tokens nem protecoes de rede, que podem ser adicionadas em uma etapa futura.
