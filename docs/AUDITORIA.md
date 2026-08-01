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

- [x] **A1. Dependências com vulnerabilidade conhecida.** `npm audit` acusa **8**
  (1 alta, 6 moderadas, 1 baixa), todas vindas de `firebase-admin` →
  `retry-request` → `teeny-request`. Precisa avaliar se `npm audit fix` resolve
  sem quebrar o push, e se não, declarar a exposição. *Resolvido: `firebase-admin`
  11 → 13.5.0, zero vulnerabilidades, 185 testes passando.*
- [x] **A2. Erros do servidor podem vazar detalhe interno.** Conferir se algum
  `catch` devolve `error.message` no corpo da resposta — mensagem de driver de
  banco conta a estrutura da tabela a quem perguntar. *Auditado: nenhuma rota
  devolve `error.message`; todas usam texto fixo. Sem ação.*
- [x] **A3. `console.log` em produção (36 ocorrências).** Precisa varrer se algum
  imprime chave, token ou payload inteiro — log de plataforma não é lugar de
  segredo. *Auditado: nenhum imprime chave; `push.js:184` imprimia o texto do
  aviso e virou contagem.*

### 2.2 Média — dívida que já cobrou juros esta semana

- [x] **B1. `monitoramento_screen.dart`: 1.543 linhas, 45 métodos.** É a tela
  onde mais bugs de campo apareceram, e não por acaso: mistura estado de
  conexão, silenciamento, agendamento, menu, diálogos e ciclo de vida. Extrair o
  menu (que virou uma tela dentro da tela) é o corte de maior retorno.
  *Feito: menu extraído para `features/monitoramento/widgets/menu_acoes_estufa.dart`
  (−305 linhas na tela, 1.543 → 1.238).*
- [ ] **B2. `estufa_routes.js`: 993 linhas, 20 rotas.** Mesma doença. Separar por
  assunto (leitura, comandos, push, chaves, agendamentos) deixaria cada arquivo
  com um motivo para mudar.
- [x] **B3. Arquitetura pela metade.** Convivem duas organizações: `features/`
  (agendamento, aparelho, home, monitoramento, notificacoes, relatorio_estufada)
  e as pastas por camada na raiz (`screens/`, `services/`, `widgets/`, `utils/`,
  `models/`). Uma migração começou e parou. Enquanto durar, ninguém sabe onde pôr
  arquivo novo. *Documentado em `ARQUITETURA.md`: destino é feature-first,
  regra de bolso definida, migração por oportunidade.*
- [x] **B4. Arquivo morto:** `features/monitoramento/widgets/relatorio_estufada_button.dart`
  não é importado por ninguém. *Removido.*
- [x] **B5. Plataforma web mantida sem uso real.** 31 usos de `kIsWeb` e **quatro
  pares** de arquivos `_web`/`_io`/`_stub` (`isar_service`, `csv_exporter`,
  `backup_file_service`, `browser_text_input`). O produto é Android. Isso é
  código que ninguém executa e todo mundo lê. *Decisão: manter — a demo web serve
  à banca do TCC. Registrado em `ARQUITETURA.md`.*

### 2.3 Baixa — higiene

- [x] **C1. Ruído de log.** 36 `console.log` + 18 `debugPrint` sem níveis. Um
  `LOG_LEVEL` mínimo evitaria escolher entre "cego" e "afogado". *Feito:
  `LOG_LEVEL` (silencioso/erro/info/debug) em `estufa_server/log.js`, 12 testes.*
- [x] **C2. `.g.dart` versionados** (≈8.500 linhas, 38% do app). É comum no
  ecossistema e a memória do projeto registra que regenerar já causou incidente —
  **manter versionado**, mas dizer isso em algum lugar. *Documentado em
  `ARQUITETURA.md` §4.*
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

### Fase 1 — Segurança e limpeza segura ✅
- [x] A1 dependências
- [x] A2 vazamento em erro
- [x] A3 varredura de log
- [x] B4 remover arquivo morto

### Fase 2 — Observabilidade ✅
- [x] C1 níveis de log no servidor

### Fase 3 — Quebrar os dois arquivos-deus
- [x] B1 extrair o menu de `monitoramento_screen`
- [ ] B2 separar `estufa_routes` por assunto

### Fase 4 — Decidir a arquitetura
- [x] B3 registrar o destino (feature-first) e migrar por oportunidade
- [x] B5 decidir sobre a web (mantida: demo para a banca)
- [x] C2 registrar a decisão sobre `.g.dart`

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
