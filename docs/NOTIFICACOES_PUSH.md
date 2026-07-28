# Notificações push (alarme, incêndio e sem comunicação)

Como o app avisa o produtor **mesmo com o celular bloqueado ou o app fechado**.
Nasceu como documento de projeto e hoje descreve o que **está implementado e
confirmado em campo** — o texto guarda o raciocínio das decisões, que continua
valendo para o TCC. O estado de cada parte está em "Estado atual no app", no fim.

## O problema

Hoje o alerta visual/sonoro do app só funciona **com o app aberto**: a tela de
monitoramento faz *polling* do status e mostra banner/sirene. Se o app estiver
em segundo plano ou fechado, o Android suspende o timer e nada é avisado.

A rede de segurança física continua sendo a **sirene do próprio aparelho**
(ESP32/buzuca), que é local e independe da internet e do celular. O push é uma
camada extra de aviso remoto — conveniência, não substitui o alarme físico.

## Os eventos a notificar

| Evento | Como a nuvem detecta |
| --- | --- |
| **Alarme de temperatura** (fora da faixa do ajuste) | Regra em `logica.js` já roda no ingest de `/leitura`. |
| **Incêndio** | `perigoChama` — o sensor de chama disparou. |
| **Temperatura muito elevada** | `riscoIncendio` — passou de 175 °F. |
| **Sem comunicação** | Ausência de leituras por 5 min (watchdog). Cobre falta de energia **e** queda de internet. |
| **Ajuste agendado** | Não vem da nuvem: é um alarme local, na hora que o produtor marcou. |

> **Nota (25/07/2026):** o risco de fogo era **um** evento com as duas causas
> juntas. Foram separados porque são independentes — o produtor pode querer
> desligar o aviso de uma sem perder o da outra —, e porque cada causa tem a
> sua própria borda: a temperatura passar do limite avisa mesmo que o sensor de
> chama já tivesse disparado antes.

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
de preferências vale para todas as estufas. A exceção por estufa prevista aqui
**foi implementada** em 24/07/2026; ver "Silenciar uma estufa" abaixo. Cada
evento tem **dois interruptores independentes**:

| Evento | Notificar (mensagem) | Tocar / vibrar |
| --- | --- | --- |
| Alarme de temperatura | on/off | on/off |
| Incêndio (sensor de chama) | on/off | on/off |
| Temperatura muito elevada (>175 °F) | on/off | on/off |
| Ajuste agendado (lembrete local) | on/off | on/off, **nasce off** |
| Sem comunicação (luz ou internet) | on/off | on/off |

### O que cada interruptor faz (25/07/2026)

Os dois nomes foram acertados depois de o produtor apontar que não descreviam o
comportamento:

- **Notificar** — manda ou não a mensagem. Se ela bipa, vibra ou só aparece na
  gaveta é decisão do **celular**, como em qualquer app; o Sentinela não mexe
  nisso. Desligado, o aviso **não é enviado** (o servidor tira aquele aparelho
  da lista) — não é "silenciar", é não existir.
- **Tocar** — decide **uma coisa só**: se aquele aviso chega como **alarme**
  (sirene longa, em volume de alarme, furando o "Não perturbe"). O rótulo era
  "Tocar / vibrar", o que sugeria mexer no bipe comum; agora é só "Tocar".

Desligar "Notificar" desliga "Tocar" junto — sem mensagem não há o que tocar.

Nada disso afeta a **sirene do aparelho**: ela é hardware, não depende do
celular nem de internet. Mesmo com tudo desligado no app, a estufa apita no
local.

### Quem acorda de madrugada

Três eventos tocam como alarme quando "Tocar" está ligado — os três em que o
produtor teria de sair da cama:

| Evento | Toca como alarme |
|---|---|
| Incêndio | sim |
| Temperatura muito elevada | sim |
| Temperatura fora da faixa | sim |
| Sem comunicação (o aparelho parou) | sim |
| "Voltou a se comunicar" | **não** — acordar alguém para dizer que está tudo bem é o oposto do útil |
| Ajuste agendado | **não por padrão** — alarme é para problema, e um lembrete que o próprio produtor marcou não é problema. Quem precisa ser acordado às 3h para pôr lenha liga o interruptor. |

**Um canal do Android por assunto**, e não um só: assim o produtor silencia o
que quiser nas configurações do sistema sem levar os outros junto. Isso corrigiu
um problema silencioso — o aviso de "sem comunicação" ia pelo canal do
**incêndio** (o watchdog o marca como crítico), então acordava, mas aparecia
como "Incêndio" nas configurações e não dava para separar um do outro.

### Medido no aparelho (Samsung, 25/07/2026)

Teste com o push de teste (`POST /push/teste`), variando só o modo de som:

| Modo do celular | Resultado |
|---|---|
| Normal | toca alto e longo |
| **"Não perturbe" ligado**, som normal | **toca** — a permissão de furar o DND funciona |
| **Silencioso** | **não toca** (a notificação chega, muda) |
| Vibrar | não toca, mas vibra |

**A conclusão que importa:** o modo **silencioso vence tudo**, inclusive o
alarme de incêndio — é o Android, não o app: o modo silencioso zera também o
volume de alarme no One UI. O "Não perturbe", esse sim, é furado pelos canais
com permissão.

Daí a recomendação que ficou escrita na própria tela: **à noite, usar "Não
perturbe" em vez de deixar o celular no silencioso**. É a diferença entre
acordar e não acordar, e nenhum ajuste no app contorna isso.

**Ressalva honesta:** os três usam a **mesma sirene**, o único som longo do app.
As vibrações diferem, mas pelo som eles são parecidos — vale um segundo arquivo
de áudio para separar "vá ver" de "corra".

**Detalhe de implementação:** com o app fechado quem escolhe som e volume é o
canal, que viaja na mensagem. Por isso o servidor lê a preferência de cada
celular e faz **dois envios** (quem quer alarme e quem quer aviso comum não
cabem no mesmo disparo), e manda um campo `acorda` no payload — "sem
comunicação" e "voltou a se comunicar" compartilham o mesmo evento, e só um dos
dois deve tocar.

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

## Silenciar uma estufa (escopo por aparelho)

Caso real: a estufada terminou naquela estufa e o produtor não quer mais ser
avisado **dela**, mas continua querendo as outras. O menu de cada estufa tem
**"Silenciar avisos"** para isso.

**A regra que governa os dois escopos:** o escopo menor **pode silenciar, nunca
dessilenciar**. Numa estufa silenciada, incêndio e sem comunicação continuam
avisando — mas só se seguirem ligados nas preferências globais. Se o produtor
desligou o incêndio para todas, silenciar uma não pode ressuscitá-lo. Isso está
travado em `estufa_app/test/silenciamento_estufa_test.dart`.

**O servidor não mudou.** Ele já filtrava por `preferencias` de cada dispositivo
(`preferenciaPermite`, em `routes/estufa_routes.js`); o app apenas registra, para
o aparelho silenciado, um conjunto **reduzido** — os eventos que sempre avisam
mantêm o valor global, e os demais vão como `notificar: false`. Como a supressão
acontece antes do envio, a estufa silenciada não recebe o push nem em segundo
plano nem com o app aberto.

**Onde cada coisa mora:** o sino da lista de estufas abre as preferências
**globais** (eventos, "Não perturbe" e a sirene dos aparelhos, que também é
global — não faz sentido calar uma estufa e deixar as outras apitando). O menu
de uma estufa tem apenas o silenciamento **daquela**. Para calar a sirene de um
único aparelho, o caminho é físico: segurar o botão do buzzer por 3 s (firmware
v1.13.0).

## Validade dos avisos (TTL) e a ponte de leitura

Dois ajustes de 24/07/2026 que atacam **falsos avisos**, os dois nascidos da
mesma pergunta: o que o alerta significa quando a rede falha em vez do aparelho.

**Validade de 30 min nos avisos de comunicação.** Quando o celular está sem
internet, o FCM guarda a mensagem e entrega na reconexão — e o produtor recebia
"estufa sem comunicação" **junto** com o "voltou a se comunicar" que a desmente,
ou pior, lia o alarme horas depois e ia até lá à toa. Avisos de estado valem
enquanto o estado vale, então expiram. **Incêndio não tem validade:** é o único
que precisa chegar por mais tarde que seja, e um teste fixa isso
(`estufa_server/test/push.test.js`).

**Ponte de leitura (app → nuvem).** Com energia na propriedade mas sem internet
lá, o aparelho não consegue publicar e o watchdog acusaria "sem comunicação" com
a estufa funcionando e o app mostrando tudo certo em LOCAL. Quando o app lê o
aparelho localmente **e tem internet própria** (4G), ele repassa a leitura via
`POST /leitura`: o `ultimoContatoMs` fica fresco e o falso alarme não chega a
nascer — melhor que desmenti-lo depois. É oportunista e barato (só em conexão
LOCAL, no máximo 1×/min, contra a cota do banco), e de brinde quem acompanha de
longe volta a ver os dados enquanto alguém estiver perto da estufa.

**O que continua sem solução por software:** se cair luz **e** internet e o
celular não tiver dados móveis, ninguém acorda o produtor remotamente — push
exige internet no celular, e o aparelho morreu junto. A saída real é um hub com
bateria e canal fora da banda (GSM/SMS); ver `VIABILIDADE_COMERCIAL.md`.

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

**Tudo o que este documento propõe está implementado** (24/07/2026), incluindo o
que ele mesmo listava como pendente: a tela de preferências, o som e a vibração
locais e a camada de push (FCM) com o app fechado — esta última **confirmada em
campo**.

Além do proposto, foram acrescentados: som em **volume de alarme** com opção de
furar o "Não perturbe" (canal `sentinela_critico_v2`), o **watchdog de silêncio**
no servidor, o **silenciamento por estufa**, a **validade** dos avisos de
comunicação e a **ponte de leitura** — todos descritos acima.

O banner de **falta de energia foi removido**, junto com o evento separado: sem
sensor de tensão e bateria, `temEnergia` era sempre `true` e o aviso nunca
aparecia, enquanto o texto prometia um gerador que não existe. Quem cobre queda
de luz é o "sem comunicação", pela ausência de leituras — a decisão está
explicada em "Por que não existe um evento separado de falta de energia".
