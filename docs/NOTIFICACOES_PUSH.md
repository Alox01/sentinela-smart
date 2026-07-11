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

Um aparelho **sem energia não consegue reportar** `temEnergia=false`. Dois
gatilhos complementares:

1. **Reporte direto:** enquanto houver bateria/nobreak, o ESP32 manda
   `temEnergia=false` e a nuvem dispara o push na hora.
2. **Watchdog de silêncio:** a nuvem guarda o horário da última leitura de cada
   estufa. Se passar de um limite (ex.: 3× o intervalo de push, ~30 min) sem
   receber nada, dispara "estufa sem comunicação" — cobre queda total de energia
   e de internet. É o gatilho mais confiável para apagão.

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

1. **Base:** projeto Firebase, `firebase_messaging`, registro de token e um push
   de teste manual (endpoint `POST /notificar-teste`).
2. **Alarme e incêndio:** disparo na borda de subida a partir do `/leitura`,
   com debounce por estado.
3. **Watchdog de energia/comunicação:** timer no servidor + push de silêncio e
   de retorno.
4. **Ajustes finos:** agrupar notificações por estufa, som/prioridade
   diferentes para incêndio, link para abrir a estufa certa no app.

## Estado atual no app

O app já **mostra** a falta de energia quando está aberto (banner âmbar na tela
de monitoramento + eventos `queda_energia` / `retorno_energia` no ciclo), lendo
`temEnergia` do status. Falta apenas a camada de push descrita acima para o
aviso funcionar com o app fechado.
