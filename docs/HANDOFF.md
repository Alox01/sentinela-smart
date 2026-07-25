# Handoff / estado do projeto

Ponto de retomada para continuar o trabalho em qualquer máquina (o histórico do
chat fica local; este arquivo e o Git são a memória portátil do projeto).
Atualizado em 24/07/2026: segurança, controle remoto, firmware real, CI,
retenção, push completo (incl. som de alarme), persistência dos ajustes,
escopo das notificações (global × por estufa), ponte de leitura e validade dos
avisos de comunicação.

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

**Firmware (ESP32, `firmware/sentinela_esp32`)** — v1.13.0, **compilado**
(86% flash / 15% RAM no core esp32 3.2.0). A v1.9.0 foi validada em hardware;
**da 1.10.0 em diante ainda não foi gravado no aparelho.**
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
- Silêncio do alarme **com prazo de 10 min** (botão e app pelo mesmo caminho);
  incêndio não silenciável.
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
  (notificar × tocar/vibrar), o "Não perturbe" e a sirene dos aparelhos são
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
- **Som de alarme** para incêndio: canal `sentinela_critico_v2`, sirene de 30s
  em volume de **alarme** (não de notificação), com opção de furar o "Não
  perturbe". Ver `NOTIFICACOES_PUSH.md`.
- **Segredos:** `google-services.json` em `estufa_app/android/app/`
  (gitignored); o **service-account nunca entra no Git nem no chat** — é env var
  no Render.

## O que falta

Nada de **produção**: o escopo da proposta está implementado. O que resta é
validação em campo e a escrita.

1. **Validar em hardware o que mudou por último** (código pronto, não provado):
   - regravar o ESP com a **1.13.0** e instalar o APK novo;
   - **teste da queda de energia** — vale por três de uma vez: mede o tempo real
     até o push de "sem comunicação", confirma que o alvo volta do NVS (e não
     nos 76 °F padrão) e fecha o ciclo com o aviso de retorno;
   - **teste do som de incêndio de madrugada**: volume de notificação baixo,
     volume de alarme alto, tela trancada. É essa combinação que a mudança do
     canal ataca;
   - **modo de configuração num celular de verdade** (portal cativo e IP fixo
     nunca foram abertos fora do código);
   - **hold de 3 s no botão do buzzer** (v1.13.0) e o efeito no app pelo LWW;
   - **cenário da ponte**: aparelho com energia e a internet da propriedade
     caída, celular no 4G — não deve nascer o falso "sem comunicação".
2. **Escrita do TCC** e seção de resultados (números dos testes acima).
3. **Provisionamento** (`CONFIGURACAO_ESP32.md`) — a maior pendência de
   software. Parte 1: botão "Cadastrar esta estufa" levando o nome mDNS ao
   formulário (metade pronta, a tela já lê e mostra o nome). Parte 2: chave
   gerada pelo aparelho, revelada só no modo de configuração (presença física) e
   propagada por TOFU — muda o servidor de chave global para chave por aparelho.
4. **Decisão em aberto:** limiar de incêndio (175 °F) — subir o valor ou trocar
   por **velocidade de subida**. Ver `AMBIENTE_ESTUFA.md` §3.
5. **Segundo ESP**: parou no teste com a placa sem nenhum jumper, para separar
   fio em pino errado de regulador queimado. Não bloqueia o TCC — um aparelho
   basta.

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
  falso não silenciável. Ver `AMBIENTE_ESTUFA.md` §3.

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
