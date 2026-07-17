# Firmware do ESP32 — Sentinela Smart

`sentinela_esp32/sentinela_esp32.ino` — controlador local do aparelho, com a
lógica original (DHT22, botões, display, LEDs, buzzer) **mais** a camada de rede
que fala o contrato do app (`docs/CONTRATO_API.md`).

> ⚠️ **Ainda não testado em hardware.** Foi escrito para o contrato; precisa ser
> validado quando o aparelho chegar (checklist em `docs/TESTE_ESP32_REAL.md`).

## Dependências (Arduino IDE → Library Manager)

- **DHT sensor library** (Adafruit)
- **TM1637Display** (Avishay Orpaz)
- **ArduinoJson** v7+ (Benoit Blanchon)

Placa: **ESP32** (instalar o core `esp32` da Espressif).

## Antes de gravar

Preencha no topo do `.ino`:

- `WIFI_SSID` / `WIFI_PASS` — Wi-Fi da propriedade;
- `DEVICE_TOKEN` — **o mesmo** token do app (campo "Chave de acesso") e do
  `ESTUFA_API_TOKEN`. Deixe `""` só para liberar comandos sem token em rede local
  confiável;
- `CLOUD_URL` — URL da nuvem para onde o aparelho empurra as leituras (histórico
  e acesso remoto). Deixe `""` para não empurrar.

O **id do aparelho é gerado automaticamente do chip (MAC)** — único por ESP, sem
configurar nada. Ao ligar, o Serial (115200) mostra o **id** (ex.:
`ESP32_A1B2C3`) e o **IP** do aparelho — o IP é o que se cadastra no app.

## O que o firmware expõe

| Rota | Função |
|---|---|
| `GET /status` | estado completo (`status` + `config`) — o app usa esta |
| `GET /` e `GET /dados` | formato simples compatível (fallback) |
| `POST /sincronizar` | ajustes com **token** e **Last-Write-Wins** por campo |

Além de servir esses endpoints, o aparelho **empurra a leitura atual para a
nuvem** (`POST CLOUD_URL/leitura`) a cada `PUSH_INTERVAL_MS`. A nuvem guarda o
estado **por aparelho** (pelo id do MAC): cada estufa no app puxa o `/status` do
seu aparelho, e o simulador continua sendo um aparelho de teste à parte. Quando
o aparelho é desligado, a nuvem para de receber e o app avisa "sem comunicação"
com a última leitura, em vez de fingir que está tudo ativo.

A lógica local continua funcionando **sem Wi-Fi** (edge-first): botões, display,
LEDs e buzzer operam offline; a rede é uma camada adicional.

## Mapeamentos e limites (v1)

- **Fahrenheit:** lido direto com `dht.readTemperature(true)`.
- **Incêndio:** o sensor de luz faz o papel de chama (`alertaIncendio` /
  `perigoChama`); alarme não silenciável. `riscoIncendio` também dispara se a
  temperatura passar de 175 °F.
- **Umidade:** o `umidadeMeta` é registrado e reportado, mas **não é atuado**
  (não há umidificador). `ventiladorLigado` fica `false` (sem relé).
- **Energia:** `temEnergia` é sempre `true` (falta o sensor de tensão — ver
  `docs/NOTIFICACOES_PUSH.md`).
- **Config não persiste** entre reinícios (alvo volta a 76 °F). Persistir em
  NVS/`Preferences` é um próximo passo (ver `docs/CONFIGURACAO_ESP32.md`).
- **Wi-Fi fixo no código:** `WIFI_SSID`/`WIFI_PASS` são constantes. Para usar em
  outra rede (ex.: casa de outra pessoa) é preciso regravar com as credenciais
  dela — ou implementar o modo de configuração por AP (ver
  `docs/CONFIGURACAO_ESP32.md`).
