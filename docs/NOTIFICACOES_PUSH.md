# Notificações push (alarme, incêndio e falta de energia)

Plano de arquitetura para o app avisar o produtor **mesmo com o celular
bloqueado ou o app fechado**. Documento de projeto — ainda não implementado.

## O problema

Hoje o alerta visual/sonoro do app só funciona **com o app aberto**: a tela de
monitoramento faz *polling* do status e mostra banner/sirene. Se o app estiver
em segundo plano ou fechado, o Android suspende o timer e nada é avisado.

A rede de segurança física continua sendo a **sirene do próprio aparelho**
(ESP32/buzuca), que é local e independe da internet e do celular. O push é uma
camada extra de aviso remoto — conveniência, não substitui o alarme físico.

## Os três eventos a notificar

| Evento | Como a nuvem detecta |
| --- | --- |
| **Alarme de processo** (temperatura fora de ±5 °F) | Regra em `logica.js` já roda no ingest de `/leitura`. |
| **Risco de incêndio / sensor de chama** | Mesmo `analisarEstado` (`riscoIncendio` / `perigoChama`). |
| **Falta de energia** | Campo `temEnergia=false` no status **ou** ausência de comunicação (ver abaixo). |

### Falta de energia é um caso especial

Um aparelho **sem energia não consegue reportar** `temEnergia=false`: silêncio é
ambíguo por natureza — "sem luz" e "sem internet" chegam do mesmo jeito (nada).
Nenhum software no celular desfaz isso sozinho. A estratégia é **transformar a
queda de energia numa mensagem explícita** em vez de silêncio. Dois gatilhos
complementares:

1. **Reporte direto:** enquanto houver bateria/nobreak, o ESP32 manda
   `temEnergia=false` e a nuvem dispara o push na hora.
2. **Watchdog de silêncio:** a nuvem guarda o horário da última leitura de cada
   estufa. Se passar de um limite (ex.: 3× o intervalo de push, ~30 min) sem
   receber nada, dispara "estufa sem comunicação" — cobre queda total de energia
   e de internet.

#### Requisito de hardware (o disambiguador)

Para o produtor saber, à distância e dormindo, se deve **abrir as estufas**, o
ESP32 precisa de:

- **Bateria / nobreak pequeno** que o mantenha vivo por alguns segundos após a
  queda da rede — tempo suficiente para enviar uma única mensagem.
- **Sensor de tensão da rede** (divisor/opto na entrada AC) para detectar a
  queda enquanto ainda está na bateria.

Sem isso, "sem luz" vs "sem internet" é impossível de distinguir remotamente.

#### Como o produtor interpreta

| O que chega | Significado | Ação |
| --- | --- | --- |
| Push **"SEM ENERGIA"** (ESP32 avisou na bateria) | Caiu a **luz** | Abrir as estufas |
| **Silêncio** → watchdog dispara "sem comunicação" | Internet do local caiu **ou** a bateria também morreu | Ir verificar / ligar para alguém |
| Leituras chegando normalmente | Tudo certo | — |

**Mensagem de causa incerta:** quando é só silêncio, o sistema é honesto sobre a
dúvida. O texto do watchdog deve dizer algo como *"parei de receber dados desta
estufa — pode ser falta de internet no local **ou** falta de energia. Verifique."*
Melhor um "vá conferir" ocasional do que perder a estufada por achar que estava
tudo bem. Esse mesmo texto vale no app aberto, quando ele entra em `OFFLINE`.

## Arquitetura proposta (FCM)

```
ESP32 / simulador  --POST /leitura-->  Servidor (nuvem)
                                          |  analisarEstado(): alarme? incêndio?
                                          |  watchdog: silêncio > limite?
                                          v
                                   Firebase Cloud Messaging (FCM)
                                          |
                                          v
                            Celular do produtor (app fechado)
                              -> notificação no sistema
```

Fluxo:

1. App registra o **token FCM** do aparelho na nuvem (`POST /dispositivos`),
   associado às estufas que o usuário acompanha.
2. A cada `/leitura`, o servidor roda `analisarEstado` e o watchdog.
3. Na **transição** para um estado de alerta (borda de subida, igual ao padrão
   `_ultimoAlertaIncendio` no app), o servidor chama a API do FCM com os tokens
   daquela estufa. Guardar o último estado notificado para não repetir.
4. FCM entrega a notificação; o Android acorda e mostra no sistema.

## Preferências de notificação (por evento)

O produtor controla os alertas de forma fina. **Escopo: global** — um conjunto
de preferências vale para todas as estufas (dá para acrescentar exceção por
estufa mais tarde, se necessário). Cada evento tem **dois interruptores
independentes**:

| Evento | Notificar (mensagem) | Tocar / vibrar |
| --- | --- | --- |
| Alarme de processo (temperatura) | on/off | on/off |
| Incêndio / sensor de chama | on/off | on/off |
| Falta de energia | on/off | on/off |
| Sem comunicação (silêncio) | on/off | on/off |

Assim ele pode, por exemplo, receber a mensagem de todos mas só deixar o celular
**tocar** para incêndio e falta de energia (o que importa de madrugada), com o
alarme de processo chegando mudo.

**Onde aplicar cada preferência:**

- **App aberto** (não precisa de FCM): ao disparar o evento, o app respeita os
  toggles — mostra/omite banner, toca som e/ou vibra.
- **App fechado** (precisa de FCM): cada evento vira um **canal de notificação
  do Android** (som/vibração por canal; o usuário ainda pode ajustar nas
  configurações do sistema). O toggle "notificar" pode **pular o envio** no
  servidor e/ou suprimir no cliente.

**Persistência:** guardar local (Isar/SharedPreferences); quando o push existir,
sincronizar com a nuvem para o servidor respeitar os eventos mutados.

**Segurança:** incêndio é o evento crítico. Permitir desligar (escolha do
usuário), mas exibir um aviso de que desativar o alerta de incêndio é arriscado —
a sirene física do aparelho continua sendo a rede de segurança independente.

## Dependências e custos

- **Projeto Firebase** (grátis) + `google-services.json` no app.
- Pacote **`firebase_messaging`** no Flutter (permissão de notificação no
  Android 13+; `POST_NOTIFICATIONS`).
- **Chave de servidor / service account** do FCM no servidor (env, fora do Git).
- **Nuvem sempre ligada.** O watchdog e o envio de push precisam de um processo
  rodando de verdade. O Render *free* dorme após ~15 min — o keep-alive ameniza,
  mas para confiar em apagão o ideal é um tier pago (ou um worker dedicado).
- Tabela nova `dispositivos` (token, estufas, `updated_at`) e uma
  `estado_notificado` por estufa para o *debounce*.

## Fases sugeridas

1. **Preferências (local, sem FCM):** tela "Notificações" no menu com a matriz
   global de toggles (notificar × tocar/vibrar por evento), persistida local, e o
   app aberto já respeitando-a (banner/som/vibração). Aviso de segurança no
   incêndio. Também melhorar o texto do indicador `OFFLINE` para a mensagem de
   causa incerta.
2. **Base FCM:** projeto Firebase, `firebase_messaging`, canais de notificação
   Android por evento, registro de token e um push de teste manual (endpoint
   `POST /notificar-teste`).
3. **Alarme e incêndio:** disparo na borda de subida a partir do `/leitura`,
   com debounce por estado, respeitando as preferências.
4. **Watchdog de energia/comunicação:** timer no servidor + push de silêncio e
   de retorno (mensagem de causa incerta).
5. **Ajustes finos:** som/prioridade diferentes para incêndio, link para abrir a
   estufa certa no app, eventual exceção de preferência por estufa.

## Estado atual no app

O app já **mostra** a falta de energia quando está aberto (banner âmbar na tela
de monitoramento + eventos `queda_energia` / `retorno_energia` no ciclo), lendo
`temEnergia` do status. Ainda **não** existem: a tela de preferências, o
som/vibração locais, a mensagem de causa incerta no `OFFLINE` e a camada de push
(FCM) para avisar com o app fechado — tudo descrito acima, a implementar.
