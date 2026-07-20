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
`ESP32_A1B2C3`), o **IP** e o **nome local** (ex.:
`sentinela-a1b2c3.local`). No app, prefira o nome local; se a rede ou o celular
não resolver mDNS, cadastre o IP exibido no Serial.

O nome mDNS funciona somente na mesma rede local e não substitui o acesso pela
nuvem. Ele evita recadastrar a estufa quando o DHCP muda o IP depois de uma
queda de energia. O suporte ESPmDNS já faz parte do core ESP32 da Espressif.

## O que o firmware expõe

| Rota | Função |
|---|---|
| `GET /status` | estado completo (`status` + `config`) — o app usa esta |
| `GET /` e `GET /dados` | formato simples compatível (fallback) |
| `POST /sincronizar` | ajustes com **token** e **Last-Write-Wins** por campo |

Além de servir esses endpoints, o aparelho **empurra a leitura atual para a
nuvem** (`POST CLOUD_URL/leitura`) a cada `PUSH_INTERVAL_MS` e **busca ajustes
feitos de longe** (`GET CLOUD_URL/comandos`) a cada `COMANDOS_INTERVAL_MS` — é
assim que um comando dado pelo app fora da propriedade chega ao equipamento,
já que o aparelho não é alcançável de fora. A nuvem guarda o
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
- **Silenciar tem prazo:** silenciar (pelo botão ou pelo app) cala a sirene por
  **10 minutos**, o mesmo `TEMPO_SILENCIO` do servidor. Passado o prazo, se a
  temperatura ainda estiver fora, ela volta a tocar. Apertar o botão de novo
  reinicia os 10 min — não religa a sirene na hora. Incêndio continua **não
  silenciável**.
- **Acomodação de 5 min:** ao mudar o alvo, o aparelho perdoa por 5 minutos
  **apenas a distância que a mudança criou** (teto de 20°F) — aproximar o alvo
  da leitura atual não perdoa nada. Serve para não alarmar enquanto a estufa
  percorre o caminho até o alvo novo. O tempo veio de medição na estufa real,
  que alcança um alvo 10–15°F acima em menos que isso; precisa ser **igual** ao
  do app e do simulador, senão o app acusa oscilação enquanto o aparelho ainda
  está perdoando. Incêndio nunca é afetado.
- **Leituras inteiras:** temperatura e umidade são arredondadas para número
  inteiro (o display tem 4 dígitos e as casas decimais não agregam).
- **A rede custa tempo do loop:** cada chamada à nuvem (push e busca de
  comandos) é um handshake HTTPS que segura o loop por 1–2 s. Por isso os
  intervalos são largos e a busca de comandos é **pulada enquanto houver
  alarme de incêndio** — em emergência o controle local fica com todo o tempo.
  Se precisar de resposta remota mais rápida, o caminho não é diminuir o
  intervalo, e sim manter a conexão aberta (WebSocket/MQTT).
- **Energia:** `temEnergia` é sempre `true` (falta o sensor de tensão — ver
  `docs/NOTIFICACOES_PUSH.md`).
- **Config persiste** entre reinícios: os ajustes de temperatura/umidade (e os
  timestamps do LWW) ficam na memória não-volátil (NVS/`Preferences`). Uma
  queda de energia não devolve mais o alvo ao padrão no meio de uma estufada.
  O **silêncio do alarme não é guardado** de propósito — depois de um reinício
  o alarme volta a valer.
- **Wi-Fi fixo no código:** `WIFI_SSID`/`WIFI_PASS` são constantes. Para usar em
  outra rede (ex.: casa de outra pessoa) é preciso regravar com as credenciais
  dela — ou implementar o modo de configuração por AP (ver
  `docs/CONFIGURACAO_ESP32.md`).
