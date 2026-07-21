# Handoff / estado do projeto

Ponto de retomada para continuar o trabalho em qualquer máquina (o histórico do
chat fica local; este arquivo e o Git são a memória portátil do projeto).
Atualizado após a rodada de jul/2026: segurança, controle remoto, firmware real,
CI, retenção, push completo (incl. som de alarme) e persistência dos ajustes.

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

**Firmware (ESP32, `firmware/sentinela_esp32`)** — v1.9.0, **compilado e validado
em hardware** (85% flash / 15% RAM no core esp32 3.2.0)
- **Configuração sem computador:** segurar os 3 botões por 3 s abre o ponto de
  acesso `Sentinela-Config`; Wi-Fi e chave saem da NVS. Trocar de roteador não
  exige mais regravar. Fecha sozinho após 5 min ocioso, e o alarme segue ativo.
  **Falta testar num celular de verdade.**
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
- Preferências por evento (notificar × tocar/vibrar), incêndio com confirmação
  para desligar.
- Disparo na **borda de subida** para incêndio, falta de energia e alarme;
  tokens recusados pelo FCM são removidos sozinhos.
- **Watchdog de silêncio**: 5 min sem reportar → "estufa sem comunicação", com
  mensagem honesta sobre a causa (luz ou internet). Ajustável por
  `WATCHDOG_SILENCIO_MIN` / `WATCHDOG_VERIFICACAO_MIN`.
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
   - regravar o ESP com a 1.8.0 e instalar o APK novo;
   - **teste da queda de energia** — vale por três de uma vez: mede o tempo real
     até o push de "sem comunicação", confirma que o alvo volta do NVS (e não
     nos 76 °F padrão) e fecha o ciclo com o aviso de retorno;
   - **teste do som de incêndio de madrugada**: volume de notificação baixo,
     volume de alarme alto, tela trancada. É essa combinação que a mudança do
     canal ataca.
2. **Escrita do TCC** e seção de resultados (números dos testes acima).
3. **Segundo ESP**: parou no teste com a placa sem nenhum jumper, para separar
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
