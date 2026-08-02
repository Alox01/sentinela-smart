# Auditoria do Sentinela Smart

> Levantamento de 31/07/2026, sobre o estado do repositório após a semana de
> testes de campo. Serve a dois fins: apontar o que corrigir, e ser o **registro
> de progresso** — cada item tem caixa, e quem retomar o trabalho sabe onde
> parou sem reler o histórico.

## Como usar este documento

Marque `[x]` ao concluir e **commite junto com a mudança**. A ordem das fases é
deliberada: cada uma depende da anterior estar estável.

## O tamanho do que se está auditando

| Área | Arquivos | Linhas |
|---|---|---|
| `estufa_app/lib` | 79 | 22.121 (≈8.500 são `.g.dart` gerados) |
| `estufa_server` | 46 | 8.043 |
| `firmware` | 2 | 2.100 |
| `docs` | 21 | 4.659 |
| Testes (app + servidor) | 33 | 4.381 |

Testes: **185 no servidor**, **71 no app**. `flutter analyze` limpo.

---

## 1. O que está bom (para não mexer sem motivo)

Vale registrar, porque auditoria que só lista defeito leva a refatorar o que
funciona:

- **SQL 100% parametrizado.** Nenhuma interpolação em query — sem superfície de
  injeção.
- **Segredos fora do versionamento.** `.env`, `google-services.json` e a
  credencial do Firebase estão no `.gitignore` e nenhum aparece em `git ls-files`.
- **Defesas HTTP no lugar:** `helmet`, `express-rate-limit` (180/min), CORS por
  lista, corpo limitado a 64 kb.
- **Comparação de token em tempo constante** (`timingSafeEqual`).
- **Nenhum módulo do servidor órfão** — todos são requeridos por alguém.
- **Poucos marcadores de dívida**: nenhum `TODO`/`FIXME`/`HACK` real no código.

---

## 2. Achados, por gravidade

### 2.1 Alta — corrigir antes de qualquer refatoração

- [x] **A1. Dependências com vulnerabilidade conhecida.** Eram **8** (1 alta, 6
  moderadas, 1 baixa). `npm audit fix` resolveu 2 sem quebrar nada (185 testes
  passando), incluindo a **alta** (`brace-expansion`, negação de serviço).
  **Sobram 6**, todas do mesmo pacote `uuid <11.1.1`, alcançado por dentro do
  `firebase-admin`. O único conserto oferecido é **rebaixar o firebase-admin da
  14 para a 10** — quatro versões maiores para trás, num pacote que é o caminho
  de todo aviso de incêndio. **Decidido não rebaixar**, e declarar: o defeito é
  falta de checagem de limite em `uuid` v3/v5/v6 quando quem chama passa o
  buffer; nada aqui chama `uuid` direto, e o `firebase-admin` não expõe esse
  caminho ao nosso código. Reavaliar quando o `firebase-admin` atualizar.
- [x] **A2. Erros do servidor podem vazar detalhe interno.** *Verificado:
  nenhuma rota devolve `error.message` no corpo — todas respondem texto fixo, e
  o detalhe fica só no log do servidor. Nada a corrigir.*
- [x] **A3. `console.log` em produção (36 ocorrências).** *Verificado: nenhum
  imprime chave, token ou senha. As ocorrências que casam com "chave" citam a
  palavra na mensagem, não o valor. O único `JSON.stringify` num log é o comando
  agendado (temperatura/umidade), que não é segredo. Nada a corrigir.*

### 2.2 Média — dívida que já cobrou juros esta semana

- [x] **B1. `monitoramento_screen.dart`: era 1.543 linhas, 45 métodos.** É a
  tela onde mais bugs de campo apareceram, e não por acaso: mistura estado de
  conexão, silenciamento, agendamento, menu, diálogos e ciclo de vida.
  *Primeiro corte (1.543 → 1.460): os três itens **informativos** do menu
  viraram widgets em `features/monitoramento/widgets/itens_menu_estufa.dart`.
  Foram escolhidos por não dependerem de nada que a tela faz — recebem um valor
  e desenham, então a extração não pôde mudar comportamento.*
  *Segundo corte, o grande (1.460 → **1.193**): a gaveta inteira saiu para
  `features/monitoramento/widgets/menu_estufa.dart` como `MenuEstufa`, que reusa
  os três widgets acima. Saíram junto os itens que ainda viviam na tela —
  silenciar avisos e compartilhar acesso —, com cinco métodos a menos no `State`
  (`_itemSilenciarAvisos`, `_legendaSilenciarAvisos`, `_silenciarAvisos`,
  `_itemCompartilharAcesso`, `_compartilharAcesso`).*
  *O acoplamento era real e continua sendo, só que agora está declarado:
  **agrupado em dois objetos** — `DadosMenuEstufa` (11 valores) e
  `AcoesMenuEstufa` (3 callbacks) — em vez de ~13 posições soltas. Descartada a
  outra saída, deixar na tela os itens com estado e passá-los prontos como
  `Widget`: ela dividiria os itens da gaveta entre dois arquivos, e o risco
  desta extração é exatamente sumir um item sem ninguém notar. Além disso, o
  caso tido como claro — silenciar avisos — não mexe em estado da tela: lê os
  singletons `SilenciamentoEstufas` e `PreferenciasNotificacaoService`, sem
  tocar em campo do `State` nem chamar `setState`. Ficaram na tela só as três
  ações que dependem mesmo dela: detalhes da conexão, configurar aparelho e
  reiniciar ajustes.*
  *Verificado: `flutter analyze` sem nenhum problema, **71 testes** passando (os
  mesmos de antes), APK de release construído com o `--dart-define`, e o
  inventário da gaveta comparado linha a linha com o do `HEAD` — os 16 itens,
  na mesma ordem e nas mesmas seções, incluindo "Compartilhar acesso", que fica
  em AVISOS e não em AÇÕES RÁPIDAS.*
- [x] **B2. `estufa_routes.js`: era 993 linhas, 20 rotas.** Mesma doença.
  *Separado por assunto. `estufa_routes.js` ficou com 84 linhas e nenhuma regra
  de negócio: cria o estado, liga os avisos e pendura os grupos (só a rota
  `/versao`, que fala do servidor e não da estufa, ficou nele). Os grupos:
  `rotas_leitura` (status, histórico, ingestão), `rotas_comandos`
  (sincronizar, caixa de comandos, botão físico), `rotas_agendamentos`,
  `rotas_push` (cadastro de token e testes) e `rotas_chaves`.*
  *Dois módulos a mais, e são eles que tornavam o corte difícil:
  `estado_estufa.js` guarda o que as rotas dividem — estado ao vivo, caixa de
  comandos pendentes, LWW — atrás de nomes em vez de `Map`s soltos; e
  `alertas_push.js` decide **quando** avisar (bordas, watchdog), separado das
  rotas de push, que só dizem **quem** recebe.*
  *Contrato preservado: `createEstufaRouter` recebe os mesmos parâmetros.
  Verificado com o inventário de rotas (método+caminho+porteira) idêntico ao de
  antes, os 191 testes passando e um servidor de fumaça confirmando que as 20
  rotas respondem e que caminho desconhecido ainda dá 404.*
- [ ] **B3. Arquitetura pela metade.** Convivem duas organizações: `features/`
  (agendamento, aparelho, home, monitoramento, notificacoes, relatorio_estufada)
  e as pastas por camada na raiz (`screens/`, `services/`, `widgets/`, `utils/`,
  `models/`). Uma migração começou e parou. Enquanto durar, ninguém sabe onde pôr
  arquivo novo.
- [x] **B4. Arquivo morto:** `features/monitoramento/widgets/relatorio_estufada_button.dart`
  não era importado por ninguém. *Removido.*
- [ ] **B5. Plataforma web mantida sem uso real.** 31 usos de `kIsWeb` e **quatro
  pares** de arquivos `_web`/`_io`/`_stub` (`isar_service`, `csv_exporter`,
  `backup_file_service`, `browser_text_input`). O produto é Android. Isso é
  código que ninguém executa e todo mundo lê. Decidir: manter (e dizer por quê)
  ou remover.

### 2.3 Baixa — higiene

- [x] **C1. Ruído de log** (no servidor). *Feito: `estufa_server/log.js` com
  `LOG_LEVEL` (silencioso/erro/info/debug), 6 testes. Todos os 54 `console.*`
  do servidor migrados — não sobrou nenhum fora dos testes. A narração de ciclo
  do simulador virou `debug` e some em produção. Os 18 `debugPrint` do app
  ficaram: lá o Flutter já os descarta em release.*
- [ ] **C2. `.g.dart` versionados** (≈8.500 linhas, 38% do app). É comum no
  ecossistema e a memória do projeto registra que regenerar já causou incidente —
  **manter versionado**, mas dizer isso em algum lugar.
- [ ] **C3. Documentação sem índice.** 21 arquivos em `docs/`, alguns já
  históricos. Um `docs/README.md` dizendo qual ler para quê.

---

## 3. Riscos que não são de código

Declarados porque o TCC deve declará-los, não porque dá para consertar hoje:

- **Sem HTTPS entre app e aparelho.** Na rede local, a chave viaja em claro. Quem
  já está no Wi-Fi da propriedade a captura. O ESP32 aguenta TLS, mas o custo de
  memória e o gerenciamento de certificado em rede doméstica não cabem no prazo.
- **Sem contas de usuário.** O modelo é "quem tem a chave, comanda". A âncora
  forte é a presença física (3 botões + PIN no visor).
- **A chave universal é extraível.** Está no firmware; foi por isso que ela ficou
  restrita a reportar leitura e registrar chave (`auth.js`).
- **Não há revogação por celular.** Chave nova tranca todos.

---

## 4. Plano de ação, por fases

Cada fase é commitável sozinha e deixa o sistema funcionando.

### Fase 1 — Segurança e limpeza segura
- [x] A1 dependências (2 de 8 resolvidas; 6 declaradas com justificativa)
- [x] A2 vazamento em erro (verificado, nada a fazer)
- [x] A3 varredura de log (verificado, nada a fazer)
- [x] B4 remover arquivo morto

### Fase 2 — Observabilidade ✅
- [x] C1 níveis de log no servidor

### Fase 3 — Quebrar os dois arquivos-deus ✅
- [x] B1 extrair o menu de `monitoramento_screen` (1.460 → 1.193)
- [x] B2 separar `estufa_routes` por assunto

### Fase 4 — Decidir a arquitetura
- [ ] B3 registrar o destino e migrar por oportunidade
- [ ] B5 decidir sobre a web
- [ ] C2 registrar a decisão sobre `.g.dart`

### Fase 5 — Documentação
- [ ] C3 índice em `docs/`
- [ ] Atualizar `HANDOFF.md` com o que esta auditoria mudou

---

## 5. O que esta auditoria NÃO cobriu

Honestidade sobre o alcance:

- **Não rodou o app em dispositivo** — a análise é estática mais o histórico de
  campo desta semana.
- **Não auditou o firmware linha a linha.** 1.992 linhas em um `.ino` único já é
  um achado por si (nenhuma separação em módulos), mas mexer nele exige o
  aparelho em mãos para validar, e ele está em produção.
- **Não mediu desempenho nem consumo de memória.**
