# Segurança dos comandos da estufa

Esta camada protege os comandos que alteram o funcionamento da estufa, como
mudança de ajuste de temperatura, mudança de ajuste de umidade e silenciamento
de alarme.

## Regra atual

- `GET /status` continua liberado para leitura do estado da estufa.
- `GET /` e `GET /dados` continuam liberados para leitura no formato simples compatível com ESP32.
- `POST /sincronizar` exige token quando o servidor estiver configurado com
  `ESTUFA_API_TOKEN`.
- `POST /debug/botao-fisico` também exige token quando configurado.

Se `ESTUFA_API_TOKEN` não estiver configurado, o servidor roda em modo de
desenvolvimento e não bloqueia os comandos. Isso facilita os testes locais com
o simulador e com protótipos do ESP32 que ainda não possuem chave.

No aplicativo, a chave pode ser configurada no cadastro/edição da estufa. Assim
cada aparelho pode ter uma chave própria. Se a chave da estufa ficar vazia, o
app usa o token global informado por `--dart-define=ESTUFA_API_TOKEN=...`, caso
ele exista.

## Como o token é enviado

O aplicativo envia o token nos cabeçalhos:

```http
Authorization: Bearer <token>
X-Device-Token: <token>
```

O servidor aceita os dois formatos. O cabeçalho `X-Device-Token` foi mantido
para facilitar a futura integração com o ESP32.

## Como testar localmente

No servidor:

```powershell
$env:ESTUFA_API_TOKEN="minha-chave-de-teste"
node server.js
```

Também existe o arquivo `estufa_server/.env.example` como modelo das variáveis
necessárias. O arquivo `.env` real deve ficar somente no computador de teste ou
no ambiente do servidor. Ao iniciar com `node server.js`, o servidor carrega
automaticamente `estufa_server/.env` quando esse arquivo existir.

No aplicativo Flutter:

```powershell
flutter run -d chrome --dart-define=ESTUFA_API_TOKEN=minha-chave-de-teste
```

Ou cadastre a estufa no app e preencha o campo
`Chave de acesso` com a mesma chave usada no servidor/ESP32.

Se o token do aplicativo estiver diferente do token do servidor, os comandos de
controle retornam `401 Não autorizado`.

## Limite desta camada

Esta medida evita que uma pessoa envie comandos simples para a estufa sem
conhecer a chave. Ela não substitui HTTPS, controle de usuários, revogação de
tokens nem proteções de rede, que podem ser adicionadas em uma etapa futura.
