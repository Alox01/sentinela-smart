# Contrato da API - Estufa Smart

Este documento define o contrato entre tres partes do projeto:

- App Flutter
- Simulador JavaScript
- Futuro aparelho fisico/controlador da estufa

O simulador pode ser removido no futuro desde que o aparelho real, ou uma API intermediaria ligada ao aparelho real, responda os mesmos endpoints e campos definidos aqui.

## Principios

- A comunicacao local deve ser priorizada.
- A nuvem deve funcionar como apoio para monitoramento remoto e persistencia.
- Configuracoes usam a regra Last Write Wins (LWW), baseada em timestamp por campo.
- Leituras de sensores representam o estado fisico atual e devem ser tratadas como dados gerados pelo dispositivo.
- Dados simulados e dados reais devem ser identificaveis no banco.

## Tipos Comuns

### StatusEstufa

Representa a leitura atual do dispositivo.

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
  "faseAtual": "1. Amarelacao",
  "aviso": "Estavel",
  "corStatus": "green"
}
```

Campos minimos exigidos pelo app hoje:

- `temperaturaAtual`: number
- `umidadeAtual`: number
- `alertaIncendio`: boolean
- `corStatus`: string
- `aviso`: string

Campos recomendados:

- `idHardware`: string
- `timestampLeitura`: integer em milissegundos Unix
- `temEnergia`: boolean
- `temInternet`: boolean
- `sinalWifi`: integer de 0 a 100
- estados dos atuadores: boolean
- `faseAtual`: string

### ConfiguracaoAlvo

Representa as metas/configuracoes desejadas pelo usuario ou pelo hardware.

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

- `temperaturaMeta` so deve sobrescrever o valor atual se `tempTimestamp` for maior que o timestamp armazenado.
- `umidadeMeta` so deve sobrescrever o valor atual se `umidTimestamp` for maior que o timestamp armazenado.
- `modoSilencioso` deve seguir a mesma regra usando `modoSilenciosoTimestamp`.
- Timestamps iguais nao devem alterar o estado.

## Endpoints

### GET /status

Retorna o estado atual da estufa e a configuracao atual.

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
    "aviso": "Estavel",
    "faseAtual": "1. Amarelacao",
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

### POST /sincronizar

Recebe alteracoes de configuracao feitas pelo app ou por outro cliente autorizado.

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

Deve ser usada quando o payload for invalido.

```json
{
  "sucesso": false,
  "erro": "Payload invalido",
  "detalhes": [
    "temperaturaMeta deve ser numero",
    "tempTimestamp deve ser inteiro positivo"
  ]
}
```

## Validacoes Recomendadas

- `temperaturaMeta`: number entre 0 e 999.
- `umidadeMeta`: number entre 0 e 100.
- `tempTimestamp`, `umidTimestamp`, `modoSilenciosoTimestamp`: inteiro positivo.
- `modoSilencioso`: boolean.
- Rejeitar payload vazio.
- Rejeitar campos desconhecidos em modo estrito, ou ignora-los com log em modo tolerante.

## Autenticacao

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

No app, esse token pode ser configurado por estufa. Se a estufa nao tiver token
proprio, o app usa o token global informado no build, quando existir.

Para apresentacao local, a autenticacao pode ficar desabilitada. Para nuvem, deve ficar habilitada.

## Simulador vs Hardware Real

O banco e a API devem diferenciar a origem dos dados:

- `simulador`: leitura gerada pelo simulador JS.
- `hardware`: leitura gerada por aparelho fisico.
- `manual`: registro ou comando criado manualmente para teste/admin.

O app nao deve depender da origem. Ele deve depender apenas deste contrato.

## Fluxo Hibrido Pretendido

1. App tenta `GET /status` no endereco local do aparelho/API local.
2. Se falhar, app tenta a API em nuvem.
3. Se ambos falharem, app entra em modo offline.
4. Comandos feitos offline ficam em fila local.
5. Ao reconectar, app envia a fila via `POST /sincronizar`.
6. O destino aplica LWW por campo e retorna a configuracao vencedora.

## Criterio Para Remover o Simulador

O simulador pode ser substituido pelo hardware real quando:

- O hardware/API real responder `GET /status` no formato acima.
- O hardware/API real aceitar `POST /sincronizar`.
- As regras de LWW estiverem testadas.
- O app conseguir operar sem alteracao de codigo, apenas trocando o endereco da estufa.
