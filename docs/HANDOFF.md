# Handoff / estado do projeto

Ponto de retomada para continuar o trabalho em qualquer máquina (o histórico do
chat fica local; este arquivo e o Git são a memória portátil do projeto).
Atualizado em 25/07/2026: segurança, controle remoto, firmware real, CI,
retenção, push completo (incl. som de alarme), persistência dos ajustes,
escopo das notificações (global × por estufa), ponte de leitura, validade dos
avisos de comunicação, **agendamento de ajuste** e **canais de alarme por
assunto**.

## Repositório oficial

`https://github.com/Alox01/sentinela-smart` — branch de deploy:
`test/http-local-device` (o Render faz auto-deploy dela). Regras de versionamento:
commits/branches em inglês, sem menção a ferramentas de IA, não usar `git add .`
cego (o Flutter gera arquivos que aparecem como modificados). Deploy verificável
em `GET /versao` (mostra o commit no ar).

## O que já funciona (implementado e verificado)

**App (Flutter/Android)**
- Monitoramento em tempo real; arquitetura híbrida com 4 estados de conexão
  automáticos: `LOCAL` (verde) → `NUVEM` (azul) → `SEM SINAL` (âmbar, aparelho
  parou de reportar) → `OFFLINE` (vermelho, celular sem alcance) → `CONECTANDO`.
- Leitura ao vivo **compartilhada** entre a home e a tela de monitoramento (um
  `EstufaMonitor` por estufa) — abrir uma estufa é instantâneo, sem busca dupla.
- Sincronização LWW por campo; fila offline de comandos; captura automática do
  `idHardware` na 1ª conexão local (+ campo manual no cadastro, para estufa só de
  nuvem/simulador).
- Relatório por estufada: resumo, gráfico (degraus + linha de ajuste, amostragem
  10 min/eventos), eventos, exportação **PDF e CSV**; apagar estufadas.
- Backup/restore local (JSON), sem a chave de acesso no arquivo exportado.

**Servidor (Node/Express, Render + Supabase)**
- Rotas: `GET /status`, `/historico`, `/`, `/dados` (autenticadas), `POST /leitura`,
  `POST /sincronizar`, `GET /comandos`, `GET /versao` (pública).
- **Estado ao vivo por aparelho** (não mistura simulador com ESP reais).
- **Caixa de comandos nuvem→aparelho** (retransmissão de comandos remotos):
  o app manda o ajuste com `idHardware`, a nuvem guarda, o aparelho busca em
  `GET /comandos` e confirma no push seguinte. Persistida no Postgres (sobrevive
  a restart). O app mostra "aguardando o aparelho" até a confirmação.
- Segurança: token obrigatório (timing-safe), servidor recusa subir sem token
  forte, helmet, rate-limit (180/min), corpo JSON ≤ 64 KB, SQL parametrizado,
  TLS no banco (validação completa com `DB_SSL_CA`). Ver `SEGURANCA.md`.
- Persistência com dedup (1 leitura/10 min + eventos) nas **duas** vias de
  escrita (`salvarSnapshot` e a ingestão `POST /leitura`) e **retenção
  automática** (~300 dias, `CLOUD_RETENTION_DAYS`). Ambas são obrigatórias:
  sem a dedup na ingestão o banco chegou a 2,7 M de linhas e estourou a cota do
  Supabase (500 MB). Ver `PLANO_BANCO_DADOS.md`.
- ESP32 virtual (push HTTP) + keep-alive contra o sleep do plano grátis.

**Firmware (ESP32, `firmware/sentinela_esp32`)** — v1.16.0, **compilado**
(86% flash / 15% RAM no core esp32 3.2.0). A **1.18.0 está gravada** no aparelho, e a
chave própria dele já está registrada na nuvem.
- **Configuração sem computador:** segurar os 3 botões por 3 s abre o ponto de
  acesso `Sentinela-Config`, com portal cativo (a página abre sozinha ao
  conectar) e a opção de IP fixo/gateway/máscara; Wi-Fi e chave saem da NVS.
  Trocar de roteador não exige mais regravar. Fecha sozinho após 5 min ocioso, e
  o alarme segue ativo. Entrada confirmada por apito + 3 LEDs (v1.11.0), já que
  o display de 7 segmentos não escreve texto legível.
  **Falta testar num celular de verdade.**
- **Sirene de temperatura desligável** (v1.12.0): pelo app (campo `buzzerAtivo`,
  LWW, NVS) ou **segurando só o botão do buzzer por 3 s** no próprio aparelho
  (v1.13.0) — para quem está na lavoura sem celular, sinal ou internet. Confirma
  com 2 apitos ao ligar e 1 longo ao desligar. **Incêndio nunca é afetado:**
  sensor de chama e temperatura de incêndio (>175 °F) tocam sempre.
- **Ajustes persistem** em memória não-volátil (NVS): queda de energia não
  devolve mais o alvo ao padrão no meio de uma estufada.
- **Acomodação de 5 min / teto de 8** após mudar o alvo, igual ao app e ao
  simulador — perdoa só a distância que a mudança criou.
- Push imediato na borda do alarme/incêndio (um teste de chama curto chegava a
  passar despercebido entre dois ciclos de 1 min).
- Controle local edge-first (DHT22, botões, display, LEDs, buzzer) sem depender
  de Wi-Fi. Id único por chip (MAC). Leituras inteiras.
- **Endereço não é identidade** (29/07/2026, achado em campo): dois ESP
  cadastrados, um deles desligado em outra casa. O endereço guardado do
  desligado passou a valer, na rede daqui, para o ESP **daqui** — e a estufa
  dele começou a exibir os dados desta. O app aprendia o `idHardware` de quem
  atendesse no endereço e **sobrescrevia** o que já sabia. Agora só aprende
  quando ainda não tem id; se quem atende é outro aparelho, recusa a leitura em
  vez de mostrar a errada. Trocar o endereço na edição limpa o id aprendido —
  é o conserto de uma estufa já apontada para o aparelho errado.
- **Fogo novo fura o silêncio** (v1.16.0): os 10 min cobrem só o fogo que já
  estava acontecendo quando o botão foi apertado — de que o produtor está
  ciente. Fogo que começa depois cancela o silêncio e toca. As duas causas
  contam separado, e uma que cessa e volta conta como nova.
- **Fogo toca contínuo, alarme comum toca intermitente** (v1.15.0): é como quem
  está na estufa, sem o celular na mão, distingue "vá ver a lenha" de "corra".
  Antes só a chama era contínua; a temperatura de incêndio caía no mesmo bipe do
  alarme comum, apesar de ser tão grave.
- Silêncio do alarme **com prazo de 10 min** (botão e app pelo mesmo caminho),
  válido também para **incêndio** desde a v1.14.0: quem aperta já está ciente e
  foi agir, e a sirene ao lado atrapalha. O prazo vence sozinho, então
  silenciar-e-esquecer continua impossível. **Desligar** o buzzer (hold de 3 s)
  segue recusado para fogo — esse não tem prazo.
- Push de leitura para a nuvem + busca de comandos (`GET /comandos`), pulada
  durante alarme de incêndio (o handshake HTTPS não pode roubar tempo do loop).
- **mDNS**: anuncia `sentinela-XXXXXX.local` (nome estável por chip), IP como
  fallback.

**Infra**
- CI (GitHub Actions): a cada push roda testes do servidor, `flutter analyze` +
  testes + build web do app, e uma **compilação real do firmware**.

**Notificações push (FCM)** — Objetivo Específico #4 da proposta, **completo e
confirmado em campo** (chegou no celular com o app fechado)
- **Dois escopos, deliberadamente separados:** as preferências por evento
  (notificar × tocar) e a sirene dos aparelhos são
  **globais** e vivem na tela aberta pelo sino da lista de estufas; o menu de
  cada estufa tem só **"Silenciar avisos"**, que cala aquela estufa. A regra é
  que o escopo menor **pode silenciar, nunca dessilenciar**: numa estufa
  silenciada incêndio e sem comunicação continuam avisando, mas apenas se
  seguirem ligados no global. Travado por testes
  (`test/silenciamento_estufa_test.dart`). O servidor não mudou — o app registra
  um conjunto reduzido de preferências para o aparelho silenciado.
- Disparo na **borda de subida** para incêndio e alarme; tokens recusados pelo
  FCM são removidos sozinhos.
- **Watchdog de silêncio**: 5 min sem reportar → "estufa sem comunicação", com
  mensagem honesta sobre a causa (luz ou internet). Ajustável por
  `WATCHDOG_SILENCIO_MIN` / `WATCHDOG_VERIFICACAO_MIN`.
- **Validade de 30 min nos avisos de comunicação** (TTL do FCM): sem ela, o
  celular que ficou sem internet recebia o "sem comunicação" **junto** com o
  "voltou a se comunicar" que o desmente. O aviso de **incêndio não tem
  validade** — é guardado indefinidamente e sempre entregue.
- **Ponte de leitura (app → nuvem):** com energia na propriedade mas sem
  internet lá, o aparelho não consegue publicar e o watchdog acusaria um falso
  "sem comunicação" com a estufa funcionando. Quando o app lê o aparelho em
  **LOCAL** e tem internet própria (4G), ele repassa a leitura (`POST /leitura`,
  no máximo 1×/min por causa da cota do banco): o `ultimoContatoMs` fica fresco
  e o alarme falso não chega a nascer.
- **Som de alarme** nos quatro avisos de risco: sirene de 30s em volume de
  **alarme** (não de notificação), um canal do Android por assunto. O card que
  pedia permissão para furar o "Não perturbe" **foi removido** — depois de
  concedida uma vez ele não controlava mais nada, e era complexidade sem
  retorno. Ver `NOTIFICACOES_PUSH.md`.
- **Dois interruptores com sentido próprio:** "Notificar" manda ou não a
  mensagem (o bipe comum é do celular, como em qualquer app); "Tocar" decide se
  ela chega como **alarme**. Quatro eventos acordam quando "Tocar" está ligado —
  incêndio, temperatura muito elevada, temperatura fora da faixa e aparelho sem
  comunicação —, cada um em **canal próprio** do Android, para o produtor
  silenciar um sem perder os outros. O "voltou a se comunicar" nunca acorda.
- **Cinco eventos:** o risco de fogo virou **dois** (sensor de chama × >175 °F),
  porque as causas são independentes e cada uma tem a sua própria borda; e o
  lembrete de ajuste agendado ganhou card próprio, com o toque **desligado por
  padrão** (alarme é para problema, e um lembrete que o produtor marcou não é).
- **Segredos:** `google-services.json` em `estufa_app/android/app/`
  (gitignored); o **service-account nunca entra no Git nem no chat** — é env var
  no Render.

**Agendamento de ajuste** — "às 14h deixe em 120 °F", para quando o produtor não
vai estar por perto
- **Aviso** = alarme local no celular (funciona sem internet nenhuma);
  **troca do ajuste** = agendador na nuvem (funciona com o app fechado). O
  Android dispara a notificação na hora, mas não roda código do app para enviar
  o comando — daí a divisão. O servidor não manda push, para o evento não chegar
  duas vezes.
- O firmware **não mudou**: o agendamento vencido entra na mesma caixa de
  comandos de um ajuste manual.
- O carimbo do LWW é a **hora agendada**, não a de aplicação: um agendamento
  atrasado não desfaz um ajuste feito à mão nesse meio tempo.
- Agendar sem sinal arma o aviso e **retenta** o registro na nuvem; se vencer
  sem registrar, o produtor é avisado de que não foi aplicado.
- Detalhes e comportamento nas falhas em `AGENDAMENTO_CURA.md`.

## O que a auditoria de 31/07 mudou

Levantamento completo em `AUDITORIA.md`, com as caixas marcadas. O resumo:

- **Segurança conferida, e pouco a consertar.** SQL 100% parametrizado, nenhum
  segredo versionado, nenhum erro de servidor vazando detalhe no corpo, nenhum
  log imprimindo chave. Das 8 vulnerabilidades de dependência, 2 foram
  resolvidas (incluindo a alta); as 6 restantes vêm do `firebase-admin` e o único
  conserto oferecido era rebaixá-lo 4 versões maiores — recusado, e declarado.
- **Os dois arquivos-deus foram quebrados.** `estufa_routes.js` foi de 993 para
  **84 linhas** (rotas separadas por assunto, mais dois módulos que guardam o
  estado compartilhado e a decisão de quando avisar). `monitoramento_screen.dart`
  foi de 1.543 para **1.193**, com a gaveta inteira num widget próprio.
- **A arquitetura ganhou destino.** `features/` é o alvo, infraestrutura fica na
  raiz, migração por oportunidade. Está em `CONVENCOES.md`, que toda sessão lê.
- **O servidor ganhou níveis de log** (`LOG_LEVEL`). Em produção vale `erro`.
- **As regras do projeto saíram da cabeça de alguém** e viraram
  `CONVENCOES.md` — commit, build, domínio, e como trabalhar em partes.

Sobrou de propósito: a **plataforma web** segue mantida sem decisão, com prazo
para decidir antes da escrita do TCC.

## O que falta

Nada de **produção**: o escopo da proposta está implementado. O que resta é
desembaraçar o cadastro, validar em campo e escrever.

1. **Validar em hardware o que mudou por último** (código pronto, não provado):
   - **modo de configuração num celular de verdade** (portal cativo e IP fixo
     nunca foram abertos fora do código);
   - **cenário da ponte**: aparelho com energia e a internet da propriedade
     caída, celular no 4G — não deve nascer o falso "sem comunicação";
   - **agendar ajuste com o ESP real** — o simulador já provou a lógica.
3. **O que 31/07 deixou na fila** (achados de campo, em ordem de valor):
   - **mostrar no app se a estufa está sendo vigiada** — uma estufa sem celular
     inscrito no push é idêntica a uma vigiada na tela. Foi assim que um aparelho
     ficou 24 h fora do ar sem ninguém ser avisado; só apareceu ao olhar o banco;
   - **o aparelho reportar o próprio IP** na leitura (a coluna `ip_local` existe
     e chega vazia). Hoje o nome mDNS é o **único** caminho local: quando ele
     falha — sufixo, roteador ou celular — não sobra nada. Com o IP guardado, o
     app ganha uma segunda porta e o diagnóstico remoto deixa de ser adivinhação;
   - **o aparelho guardar a chave universal como reserva**, para registrar a
     própria quando a dele for recusada. É a metade que falta da separação de
     credenciais: sem ela, um aparelho que perde a chave ainda precisa de socorro
     manual (aconteceu em 31/07);
   - **PIN de 4 dígitos no visor** (`SEGURANCA_COMANDOS.md`, Modelo B) — hoje o
     ponto de acesso do modo de configuração é aberto, e quem estiver ao alcance
     naquele momento pode pedir `/config/identidade` e levar a chave;
   - **compartilhar acesso entre celulares** — vários celulares já comandam a
     mesma estufa (a chave é do aparelho, e o push é por celular); o que falta é
     o segundo celular receber a chave sem entrar no modo de configuração, que
     tira o aparelho do ar. Ressalva: com chave por aparelho não há como revogar
     um celular só;
   - **limpar inscrições órfãs de push** (ex.: `ESP32_182EC8`, de uma estufa já
     removida do app).
4. **Sons próprios por aviso** — aguardando os áudios do produtor. Requisitos e
   a pegadinha do canal congelado em `NOTIFICACOES_PUSH.md`.
5. **Escrita do TCC** e seção de resultados (números dos testes acima).
   Ordem sugerida do trabalho daqui em diante: `PLANO_POS_TESTES.md`.
6. **Provisionamento Parte 2 — implementada e registrando em campo**
   (29/07/2026, firmware 1.18.0 + servidor): o aparelho registrou a chave
   própria sozinho, no ciclo de comandos. O app também leva a chave (caminho B).
   Falta provar a **rotação** ("gerar nova chave" no modo de configuração) e, só
   depois, decidir desligar a chave global (`ESTUFA_API_TOKEN`) — que continua valendo de propósito, senão os
   aparelhos que ainda não registraram a sua perderiam o acesso remoto. Detalhes
   e as decisões de segurança em `CONFIGURACAO_ESP32.md`.
7. **Segundo ESP**: parou no teste com a placa sem nenhum jumper, para separar
   fio em pino errado de regulador queimado. Não bloqueia o TCC — um aparelho
   basta.

Fechado desde a última revisão: o **limiar de incêndio** fica em 175 °F, com
dado de campo do produtor (`AMBIENTE_ESTUFA.md` §3), e o **hold de 3 s** no
botão do buzzer foi validado no aparelho.

Adiado por escolha: **guardar o IP resolvido do nome mDNS** para acelerar as
transições de conexão. Só ganha velocidade, não corrige nada quebrado, e essa
parte do app já produziu vários problemas de campo.

## Bloqueado por hardware (trabalho futuro honesto — ver §6.2 do outline)

- **Distinção definitiva luz × internet:** exige bateria/nobreak + sensor de
  tensão no ESP para ele avisar "sem energia" antes de morrer. Hoje `temEnergia`
  é sempre `true` no firmware. O watchdog de silêncio cobre o caso genérico.
- **Controle de ventoinha / agendamento (menu Fase B):** exige relé no aparelho.
- **Sensores da versão final (2):** o protótipo tem um DHT22 só, de teste. A
  instalação real usa **dois pontos distintos** (temperatura na saída de ar
  quente, umidade dentro da massa), com **cabo longo** até o aparelho — e o
  DHT22 não atende a nenhum dos três requisitos (margem térmica, umidade, cabo).
  Ambiente da estufa, posições, temperaturas e a direção recomendada
  (DS18B20 estanque + SHT31/RS485) estão em **`AMBIENTE_ESTUFA.md`**.
  Aguardando a metragem dos cabos para fechar a escolha da umidade.
- **Limiar de incêndio (175 °F) apertado:** a máxima de trabalho é 165 °F e o
  sensor fica no ar mais quente da estufa — 10 °F de folga. Risco de alarme
  falso, que desde a v1.14.0 pode ao menos ser silenciado por 10 min (antes não
  podia de jeito nenhum). Ver `AMBIENTE_ESTUFA.md` §3.

## Trabalho futuro de software

- **Criptografia da NVS:** a senha do Wi-Fi e a chave de acesso ficam em claro
  na memória do ESP32. Exigiria *flash encryption*, que complica gravação e
  manutenção. Documentado como limitação em `CONFIGURACAO_ESP32.md`.
- **Agendamento da curva de cura:** trocar sozinho o alvo a cada fase. Como o
  aparelho não tem atuador, agendaria a **referência do alarme**, não o
  aquecimento. O lugar certo é o firmware, com tempo **relativo** ao início da
  estufada (sem depender de NTP nem de internet); o obstáculo é o LWW, que hoje
  sincroniza campos simples e não listas. Análise e passo intermediário barato
  (presets por fase) em `AGENDAMENTO_CURA.md`.

## Desvios em relação à proposta (avisar o orientador)

- **Autenticação por chave de acesso**, não "de usuários" (Obj. Específico #2):
  o sistema é de produtor único; não há cadastro/contas. Reformular o objetivo,
  não omitir.
- **Backend em Node.js puro**, não TypeScript (a proposta dizia "Node.js com
  TypeScript, ou Python"). Sem impacto técnico.

## Build do APK

Sempre **release** (bug do Isar em debug):
```
flutter build apk --release --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

## Verificação

- Servidor: `cd estufa_server && npm test` · App: `cd estufa_app && flutter analyze lib test && flutter test` · Firmware: compilar no Arduino IDE / arduino-cli (core esp32 3.2.0).
- Deploy no ar: `GET https://estufa-server.onrender.com/versao` → commit atual.
- Em 25/07/2026: **160 testes no servidor**, **57 no app**, analyze limpo,
  firmware 1.16.0 compilando em 86% do flash.
- Testar alarme sem esperar acontecer: `POST /push/verificar-silencio` (roda o
  watchdog na hora) e `POST /agendamentos/verificar` (aplica o que venceu).
  Ambos autenticados.
- Canal novo do Android só nasce quando o app **abre** depois de instalado, e um
  canal existente **não se reconfigura** — mudar som ou importância exige
  incrementar o sufixo do id (`_v1` → `_v2`), senão a mudança não vale para quem
  já tinha o app.
