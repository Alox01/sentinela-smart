# Contrato da API - Sentinela Smart

Este documento define o contrato entre três partes do projeto:

- App Flutter
- Simulador JavaScript/servidor local
- Aparelho físico ESP32 ou controlador equivalente

O simulador pode ser removido no futuro desde que o aparelho real, ou uma API intermediária ligada ao aparelho real, responda os mesmos endpoints e campos definidos aqui.

## Princípios

- A comunicação local deve ser priorizada quando app e aparelho estiverem na mesma rede.
- A nuvem deve funcionar como apoio para monitoramento remoto e persistência.
- Ajustes usam a regra Last Write Wins (LWW), baseada em timestamp por campo.
- Leituras de sensores representam o estado físico atual e devem ser tratadas como dados gerados pelo dispositivo.
- Dados simulados e dados reais devem ser identificáveis no banco.
- Comandos de controle devem ser validados antes de alterar o equipamento.

## Formato completo do servidor

### StatusEstufa

Representa a leitura atual do dispositivo no formato completo usado pelo simulador e pelo servidor local.

```json
{
  "idHardware": "ESP32_REALISTIC_V2",
  "timestampLeitura": 1710000000000,
  "temperaturaAtual": 90.2,
  "umidadeAtual": 80.0,
  "temEnergia": true,
  "temInternet": true,
  "sinalWifi": 95,
  "alertaIncendio": false,
  "ventiladorLigado": false,
  "aquecedorLigado": true,
  "umidificadorLigado": false,
  "faseAtual": "1. Amarelação",
  "aviso": "Estável",
  "corStatus": "green"
}
```

Campos mínimos exigidos pelo app hoje:

- `temperaturaAtual`: number
- `umidadeAtual`: number
- `alertaIncendio`: boolean
- `corStatus`: string
- `aviso`: string

Campos recomendados:

- `idHardware`: string
- `timestampLeitura`: inteiro em milissegundos Unix
- `temEnergia`: boolean
- `temInternet`: boolean
- `sinalWifi`: inteiro de 0 a 100
- estados dos atuadores: boolean
- `faseAtual`: string

### ConfiguracaoAlvo

Representa os ajustes desejados pelo usuário ou pelo hardware. Os nomes dos campos ainda usam `Meta` porque fazem parte do contrato interno já implementado, mas na interface do app o termo exibido ao usuário é "ajuste".

```json
{
  "idHardware": "ESP32_REALISTIC_V2",
  "temperaturaMeta": 90.0,
  "tempTimestamp": 1710000000000,
  "umidadeMeta": 99.0,
  "umidTimestamp": 1710000000000,
  "modoSilencioso": false,
  "modoSilenciosoTimestamp": 1710000000000
}
```

Regras:

- `temperaturaMeta` só deve sobrescrever o valor atual se `tempTimestamp` for maior que o timestamp armazenado.
- `umidadeMeta` só deve sobrescrever o valor atual se `umidTimestamp` for maior que o timestamp armazenado.
- `modoSilencioso` deve seguir a mesma regra usando `modoSilenciosoTimestamp`.
- Timestamps iguais não devem alterar o estado.

## Formato simples compatível com ESP32

O protótipo ESP32 testado respondeu um JSON simples na raiz do endereço, por exemplo `http://192.168.1.21/`. O servidor/simulador também expõe esse formato em `GET /` e `GET /dados` para facilitar testes sem o aparelho físico.

```json
{
  "temperaturaF": 95.2,
  "umidade": 65.0,
  "temperaturaAlvoF": 95,
  "umidadeAlvo": 65,
  "margemF": 8,
  "alertaTemperatura": false,
  "alertaLuz": false,
  "mostrandoUmidade": false,
  "modoAjuste": false,
  "buzzerSilenciado": false,
  "ledControleLigado": true,
  "leituraOk": true,
  "ip": "192.168.1.21"
}
```

Campos mínimos para leitura no app:

- `temperaturaF`: number
- `umidade`: number
- `temperaturaAlvoF`: number
- `alertaTemperatura`: boolean
- `alertaLuz`: boolean
- `leituraOk`: boolean

Campos opcionais recomendados:

- `umidadeAlvo`: number, para o app diferenciar umidade lida e ajuste de umidade. O simulador local já envia esse campo; o ESP32 atual ainda pode omitir.
- `tokenConfigurado`: boolean, para indicar se o aparelho exige chave de acesso.
- `versaoFirmware`: string, para diagnóstico.

Quando o ESP32 não enviar `umidadeAlvo`, o app usa a umidade lida como referência visual. Isso mantém o protótipo funcionando sem bloquear a evolução futura.

## Endpoints

### GET /status

Retorna o estado atual da estufa e a configuração atual no formato completo.

#### Resposta 200

```json
{
  "status": {
    "idHardware": "ESP32_REALISTIC_V2",
    "timestampLeitura": 1710000000000,
    "temperaturaAtual": 90.2,
    "umidadeAtual": 80.0,
    "alertaIncendio": false,
    "corStatus": "green",
    "aviso": "Estável",
    "faseAtual": "1. Amarelação",
    "aquecedorLigado": true,
    "ventiladorLigado": false,
    "umidificadorLigado": false
  },
  "config": {
    "idHardware": "ESP32_REALISTIC_V2",
    "temperaturaMeta": 90.0,
    "tempTimestamp": 1710000000000,
    "umidadeMeta": 99.0,
    "umidTimestamp": 1710000000000,
    "modoSilencioso": false,
    "modoSilenciosoTimestamp": 1710000000000
  }
}
```

### GET /

Retorna o formato simples compatível com o ESP32. No aparelho físico, essa foi a rota usada no teste inicial.

### GET /dados

Também retorna o formato simples compatível com o ESP32. No simulador, ela existe para deixar explícito que a resposta é uma leitura simples do dispositivo.

### POST /sincronizar

Recebe alterações de ajuste feitas pelo app ou por outro cliente autorizado.

#### Body para alterar temperatura

```json
{
  "temperaturaMeta": 95.0,
  "tempTimestamp": 1710000005000
}
```

#### Body para alterar umidade

```json
{
  "umidadeMeta": 85.0,
  "umidTimestamp": 1710000005000
}
```

#### Body para silenciar alarme

Formato recomendado para substituir o formato antigo `{"comando":"silenciar"}`:

```json
{
  "modoSilencioso": true,
  "modoSilenciosoTimestamp": 1710000005000
}
```

#### Resposta 200

```json
{
  "sucesso": true,
  "alteracoesAplicadas": ["temperaturaMeta"],
  "alteracoesIgnoradas": [],
  "configAtualizada": {
    "idHardware": "ESP32_REALISTIC_V2",
    "temperaturaMeta": 95.0,
    "tempTimestamp": 1710000005000,
    "umidadeMeta": 99.0,
    "umidTimestamp": 1710000000000,
    "modoSilencioso": false,
    "modoSilenciosoTimestamp": 1710000000000
  }
}
```

#### Resposta 400

Deve ser usada quando o payload for inválido.

```json
{
  "sucesso": false,
  "erro": "Payload inválido",
  "detalhes": [
    "temperaturaMeta deve ser número",
    "tempTimestamp deve ser inteiro positivo"
  ]
}
```

### POST /leitura

Rota de ingestão de telemetria. Serve para o hardware (ou uma ponte) enviar
uma leitura para ser persistida no histórico em nuvem. Enquanto o ESP32 físico
não existe, o simulador continua alimentando o histórico pelo agendador
periódico; esta rota deixa a arquitetura pronta para o aparelho real sem
depender desse polling.

Exige token quando o servidor estiver configurado com `ESTUFA_API_TOKEN`.

#### Body

```json
{
  "idHardware": "ESP32_CAMPO_01",
  "timestampLeitura": 1710000000000,
  "temperaturaAtual": 142.5,
  "umidadeAtual": 38.0,
  "alarmeAtivo": false,
  "faseAtual": "3. Secagem da lamina",
  "fonte": "hardware"
}
```

Campos mínimos: `temperaturaAtual` (number) e `umidadeAtual` (number, 0 a 100).
`fonte` é opcional e assume `hardware` quando ausente. Um objeto `config`
opcional pode acompanhar a leitura para atualizar os ajustes do dispositivo.

#### Respostas

- Gravou na nuvem:

```json
{ "sucesso": true, "persistido": true }
```

- Nuvem indisponível no momento (a leitura foi guardada no buffer offline local
  e será reenviada quando a conexão voltar):

```json
{ "sucesso": true, "persistido": false, "motivo": "bufferizado" }
```

- Persistência desabilitada (servidor sem `DATABASE_URL`, modo demonstração):

```json
{ "sucesso": true, "persistido": false, "motivo": "persistencia_desabilitada" }
```

- Payload inválido: `400` no mesmo formato de `POST /sincronizar`.

#### Buffer offline de leituras

Quando o banco em nuvem está configurado mas fica temporariamente inacessível,
as leituras são gravadas em um arquivo local (`.buffer_leituras.jsonl`) e
reenviadas em ordem cronológica assim que a conexão volta. É o espelho, para o
lado das leituras, da fila offline que o app já mantém para os comandos.

## Validações recomendadas

- `temperaturaMeta`: number entre 60 e 200.
- `umidadeMeta`: number entre 0 e 100.
- `tempTimestamp`, `umidTimestamp`, `modoSilenciosoTimestamp`: inteiro positivo.
- `modoSilencioso`: boolean.
- Rejeitar payload vazio.
- Rejeitar campos desconhecidos em modo estrito, ou ignorá-los com log em modo tolerante.

## Autenticação

Quando `ESTUFA_API_TOKEN` estiver configurado, clientes devem enviar:

```http
Authorization: Bearer <token>
```

ou:

```http
X-API-Token: <token>
```

ou:

```http
X-Device-Token: <token>
```

No app, essa chave pode ser configurada por estufa. Se a estufa não tiver chave própria, o app usa a chave global informada no build, quando existir.

**Todas as rotas exigem o token quando ele está configurado — inclusive as de
leitura** (`GET /status`, `/historico`, `/`, `/dados`). Telemetria da estufa é
dado do produtor, não público: sem essa exigência, qualquer pessoa com a URL da
nuvem leria as leituras de qualquer aparelho. Consequência prática: uma estufa
cadastrada **sem** chave de acesso no app não consegue ler pela nuvem (as rotas
respondem 401). No aparelho local o `GET /status` continua aberto na rede da
propriedade (edge-first); apenas os comandos exigem token lá.

Para apresentação local, a autenticação pode ficar desabilitada
(`PERMITIR_SEM_TOKEN=true`). Para nuvem ou rede exposta, deve ficar habilitada —
o servidor se recusa a subir sem um token forte.

## Simulador vs hardware real

O banco e a API devem diferenciar a origem dos dados:

- `simulador`: leitura gerada pelo simulador JS.
- `hardware`: leitura gerada por aparelho físico.
- `manual`: registro ou comando criado manualmente para teste/admin.

O app não deve depender da origem. Ele deve depender apenas deste contrato.

## Fluxo híbrido pretendido

1. App tenta `GET /status` no endereço local do aparelho/API local.
2. Se `/status` não existir, app tenta ler o JSON simples da raiz (`GET /`).
3. Se falhar localmente, app tenta a API em nuvem quando ela estiver configurada.
4. Se ambos falharem, app entra em modo offline.
5. Comandos feitos offline ficam em fila local.
6. Ao reconectar, app envia a fila via `POST /sincronizar`.
7. O destino aplica LWW por campo e retorna a configuração vencedora.

### Comando pela nuvem (`GET /comandos`)

Na rede local o destino do `POST /sincronizar` é o próprio aparelho, que aplica
o LWW na hora. **Pela nuvem isso não é possível:** o aparelho fica atrás do
roteador da propriedade e não é alcançável de fora — quem inicia toda conversa
é ele. Sem uma caixa de comandos, o ajuste feito de longe não chegava ao
equipamento (e o servidor ainda o aplicava no simulador, fazendo o app relatar
sucesso sem que nada acontecesse).

O caminho remoto, então, é:

1. App envia `POST /sincronizar` incluindo o campo **`idHardware`** de destino.
2. A nuvem **não aplica** o comando: guarda-o na caixa daquele aparelho e
   responde `{"sucesso": true, "pendente": true}`. Quando o `idHardware` é o do
   simulador (ou não vem), o comportamento antigo é mantido e o simulador aplica.
3. O aparelho consulta `GET /comandos?idHardware=<o seu>` periodicamente
   (autenticado, mesmo token das demais rotas) e recebe
   `{"idHardware": "...", "comando": {...}}` ou `comando: null`.
4. O aparelho aplica pelo **mesmo LWW por campo** usado no `/sincronizar` local
   e empurra a leitura em seguida.
5. O `POST /leitura` carrega a configuração do aparelho — é por ela que a nuvem
   sabe que o comando foi obedecido (o campo saiu da caixa quando o timestamp
   reportado é igual ou mais novo que o pendente). Não existe rota de _ack_.
6. Até essa confirmação, a caixa **continua entregando** o comando a cada
   consulta. Reaplicar é inofensivo — o LWW no aparelho torna a operação
   idempotente — e cobre o caso de o aparelho reiniciar logo após buscar.

Enquanto houver comando pendente, `GET /status` devolve a configuração do
aparelho **com o pendente por cima** e marca `aguardandoAparelho: true`. Sem
isso, a tela do app voltaria ao valor antigo poucos segundos depois do comando,
já que a leitura ao vivo ainda é a anterior — parecendo que o ajuste falhou.

Comandos acumulados na caixa se fundem por campo: dois ajustes de temperatura,
o mais novo vence; temperatura e silenciar convivem. Como o LWW final é do
aparelho, uma entrega duplicada ou fora de ordem não causa dano.

## Critério para remover o simulador

O simulador pode ser substituído pelo hardware real quando:

- O hardware/API real responder `GET /status` ou `GET /` em um dos formatos aceitos.
- O hardware/API real aceitar comandos equivalentes aos de `POST /sincronizar`, ou existir uma API intermediária que traduza os comandos para o aparelho.
- As regras de LWW estiverem testadas.
- O app conseguir operar sem alteração de código, apenas trocando o endereço da estufa.
