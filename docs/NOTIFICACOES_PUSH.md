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
| **Sem comunicação** | Ausência de leituras por 5 min (watchdog). Cobre falta de energia **e** queda de internet. |

### Por que não existe um evento separado de "falta de energia"

Existiu, e foi **removido**. Um aparelho **sem energia não consegue reportar**
`temEnergia=false` — ele morre antes. Sem sensor de tensão e sem bateria,
`temEnergia` é fixo em `true` no firmware, então esse evento **nunca podia
disparar**: era uma opção na tela que não correspondia a nada.

Pior que inútil, era arriscado. O produtor podia manter "Falta de energia"
ligada e desligar "Sem comunicação" por achar redundante — e ficar **sem aviso
nenhum** exatamente no cenário que motiva o projeto. A tela prometia uma
distinção que o sistema não sabe fazer.

Silêncio é ambíguo por natureza: "sem luz" e "sem internet" chegam do mesmo
jeito (nada). Então há **um** evento, `semComunicacao`, e a mensagem assume a
dúvida: *"pode ser falta de energia ou de internet no local. Verifique."*

O evento separado volta a fazer sentido **quando existir o sensor de tensão** —
aí o aparelho consegue afirmar a causa antes de desligar, e a distinção passa a
ser real em vez de prometida.

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
| Sem comunicação (luz ou internet) | on/off | on/off |

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

1. ✅ **Preferências (local, sem FCM) — FEITO.** Tela "Notificações" no menu da
   estufa com a matriz global (notificar × tocar/vibrar por evento), persistida
   com `shared_preferences`, carregada no boot. Confirmação ao desligar incêndio.
   Código em `estufa_app/lib/features/notificacoes/`
   (`models/preferencias_notificacao.dart`, `services/…_service.dart` singleton
   `PreferenciasNotificacaoService.instance`, `screens/notificacoes_screen.dart`).
   **Ainda falta desta fase:** som/vibração e supressão de banner com o app
   aberto respeitando os toggles — entra junto da Fase 3 (hoje o app só mostra
   banner visual, não toca som). E o texto de "causa incerta" no `OFFLINE`.
2. ✅ **Base FCM — FEITO.** App: `firebase_messaging` + `flutter_local_notifications`,
   canais Android (`sentinela_alertas`, `sentinela_critico`), registro do token
   por estufa (`PushNotificationService`). Servidor: `push.js` (envio via
   `firebase-admin`), tabela `push_dispositivos`, rotas
   `POST`/`DELETE /push/dispositivos` e `POST /push/teste`.
3. ✅ **Alarme e incêndio — FEITO.** `avaliarAlertas` no `POST /leitura` dispara
   **na borda de subida** (não repete enquanto o problema dura) para incêndio,
   falta de energia e alarme de temperatura, respeitando as preferências
   salvas por aparelho. Tokens recusados pelo FCM são removidos sozinhos.
4. ✅ **Watchdog de energia/comunicação — FEITO.** `watchdog.js` verifica a cada
   **1 min** os aparelhos que têm alguém inscrito no push. Passando **5 min** sem
   reportar, dispara "estufa sem comunicação" com a **mensagem de causa
   incerta** (luz ou internet); avisa de novo só quando **volta** a reportar.
   Último contato vem do estado ao vivo, com fallback no banco — assim um
   aparelho que morreu antes de um restart do servidor continua sendo vigiado.
   Rota `POST /push/verificar-silencio` roda a checagem na hora, para testar sem
   esperar os 5 minutos.

   O limite é **5 pushes perdidos** (o aparelho reporta a cada 60s). Descer mais
   que isso gera alarme falso: um roteador reiniciando ou uma reconexão de Wi-Fi
   levam 1–2 min de silêncio normal. Para afinar sem regravar o servidor, use as
   variáveis `WATCHDOG_SILENCIO_MIN` e `WATCHDOG_VERIFICACAO_MIN` (em minutos);
   valor ausente ou inválido cai no padrão.
5. ✅ **Som de alarme para incêndio — FEITO.** O alerta de incêndio precisa
   acordar alguém às 3h da manhã, e o bipe padrão de notificação dura ~2s.

   **O detalhe que decide tudo:** com o app fechado, o código Dart não roda —
   quem desenha a notificação é o Android, usando **só o que está no canal**.
   Então o que acorda o produtor é a configuração do canal, não o
   `AndroidNotificationDetails`.

   O canal `sentinela_critico_v2` usa som de 30s (`res/raw/alarme_estufa.wav`,
   gerado por `estufa_app/tools/gerar_som_alarme.js`) com
   `audioAttributesUsage: alarm` — toca no **volume de alarme**, não no de
   notificação, que costuma ficar baixo. Mais vibração longa e `bypassDnd`.

   **Por que `_v2`:** o Android congela som e importância de um canal já
   criado. Manter o id antigo deixaria quem já tinha o app com o bipe curto
   para sempre. O id é fixado por teste (`test/push.test.js`) porque um id
   divergente entre app e servidor não gera erro nenhum — só tira o som,
   calado.

   **"Não perturbe":** `ACCESS_NOTIFICATION_POLICY` no manifesto **não basta**.
   O produtor libera numa tela do sistema, pelo botão na tela de Notificações.
   A permissão precisa vir **antes** de criar o canal, senão o Android ignora o
   `bypassDnd` em silêncio — por isso `inicializar()` pede a permissão primeiro
   e, quando o produtor libera depois, o canal é apagado e recriado. Em algumas
   versões do Android o sistema restaura os ajustes do canal apagado; nesses
   aparelhos pode ser preciso ligar na mão nas configurações.

   **Não vence o modo silencioso** do aparelho — isso exigiria mexer no
   `RingerMode`, o que o app não faz.
6. **Alarme contínuo (não feito):** tocar sem parar até alguém apertar "parar",
   como despertador. Exigiria mensagem só de dados, `fullScreenIntent`, tela
   própria e serviço em primeiro plano — e no Android 14+ o recurso é restrito
   a apps de chamada e despertador, com permissão à parte. Avaliado e adiado:
   o som de 30s em volume de alarme resolve a maior parte do problema.
7. **Ajustes finos:** link para abrir a estufa certa no app, eventual exceção
   de preferência por estufa.

## Como ligar o push (configuração)

O código está pronto; falta **só a credencial no servidor**:

1. `google-services.json` → já está em `estufa_app/android/app/` (gitignored).
2. **service-account JSON** → **nunca** no Git nem no chat. No painel do Render,
   criar a variável **`FIREBASE_SERVICE_ACCOUNT`** e colar o **conteúdo do JSON**
   (aceita o JSON cru ou em base64 — o base64 evita problema com as quebras de
   linha da chave privada).

Sem essa variável o servidor sobe normal e apenas registra
`Push desabilitado: FIREBASE_SERVICE_ACCOUNT nao configurado` — o push é camada
extra, não caminho crítico.

### Verificar ponta a ponta

Com o app instalado e uma estufa cadastrada (com `idHardware` preenchido):

```
curl -X POST https://estufa-server.onrender.com/push/teste \
  -H "X-Device-Token: <a chave de acesso>" \
  -H "Content-Type: application/json" \
  -d '{"idHardware":"ESP32_XXXXXX"}'
```

Resposta traz `enviados` e `inscritos`. Se `inscritos` for 0, o app ainda não
registrou o token (abrir o app com internet e a estufa cadastrada).

## Estado atual no app

O app já **mostra** a falta de energia quando está aberto (banner âmbar na tela
de monitoramento + eventos `queda_energia` / `retorno_energia` no ciclo), lendo
`temEnergia` do status. Ainda **não** existem: a tela de preferências, o
som/vibração locais, a mensagem de causa incerta no `OFFLINE` e a camada de push
(FCM) para avisar com o app fechado — tudo descrito acima, a implementar.
