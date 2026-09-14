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
  na mesma ordem e nas mesmas seções, incluindo "Compartilhar acesso", que
  ficava em AVISOS. **Essa posição era herança da tela antiga**, preservada aqui
  só para o refactor não mudar comportamento — e virou CONEXÃO em 05/08/2026,
  junto com "Tirar acesso dos outros celulares": os dois decidem quem comanda a
  estufa, o que não é assunto de aviso.*
  *Essa conferência virou teste: `estufa_app/test/menu_estufa_test.dart` (5
  testes) monta `MenuEstufa` e afirma as 16 posições na ordem, as três seções e
  a seção de cada item. Nenhuma mudança na produção foi necessária — os três
  singletons que o menu toca já respondem sem inicialização (`Set` vazio,
  preferências padrão) e o `PushNotificationService` só é alcançado ao tocar no
  interruptor, o que o teste não faz. Provado com duas regressões plantadas —
  apagar `ItemSireneDoAparelho` e apagar o título AVISOS: `flutter analyze`
  continuou limpo nas duas, e o teste falhou (3 e 4 testes, respectivamente).
  Total do app: **76 testes**.*
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
- [x] **B3. Arquitetura pela metade.** Convivem duas organizações: `features/`
  (agendamento, aparelho, home, monitoramento, notificacoes, relatorio_estufada)
  e as pastas por camada na raiz (`screens/`, `services/`, `widgets/`, `utils/`,
  `models/`). Uma migração começou e parou. Enquanto durar, ninguém sabe onde pôr
  arquivo novo. *Destino declarado em `CONVENCOES.md`: `features/` é o alvo,
  infraestrutura fica na raiz, e a migração é **por oportunidade** — mover em
  bloco produz um commit que ninguém revisa e apaga o histórico de quem mexeu no
  quê. Motivado por um caso real: uma tela nova criou `features/home/screens/`
  porque a pasta não existia, sem que isso fosse decisão de ninguém.*
- [x] **B4. Arquivo morto:** `features/monitoramento/widgets/relatorio_estufada_button.dart`
  não era importado por ninguém. *Removido.*
- [x] **B5. Plataforma web mantida sem uso real.** Usos de `kIsWeb` e quatro
  pares de arquivos `_web`/`_io`/`_stub`. Código que ninguém executa e todo mundo
  lê. *Ficou em aberto em 01/08 — podia servir de demonstração na banca — e a
  decisão veio em **04/08/2026: só Android e iOS**. A web saiu inteira, e junto
  `linux/`, `macos/` e `windows/`. O que decidiu foi o custo aparecer no mesmo
  dia: remover o backup exigiu editar os dois lados do banco, e a remoção
  automática levou junto o `_limparHistoricoAntigo` do lado web — o lado que
  ninguém executa quase quebrou a retenção do lado que todo mundo executa. Ver
  `CONVENCOES.md`, que agora registra também o que falta para o iOS existir de
  verdade.*

### 2.4 Achado em campo (05/08/2026)

- [x] **D1. A interface entrega a chave por cópia, e as cópias envelhecem.**
  A tela de monitoramento recebe `tokenAcesso` de quem a abriu; o cartão da lista
  recebe da lista; a lista recebe do banco quando carregou. Trocar a chave lá
  dentro grava **no banco** e não nesses três lugares.

  *Já cobrou caro.* Reabrir a estufa depois de revogar devolvia a chave velha, o
  `MonitorEstufas` via "nada mudou" e reusava o `ApiService` antigo: todo comando
  virava "Chave inválida", **inclusive na rede local com o aparelho ao lado**, e
  só reiniciar o app resolvia. Levou uma tarde para ser encontrado, porque o
  sintoma apontava para o aparelho, para a nuvem e para o firmware — nunca para a
  interface. Corrigido **num caminho só** (a lista recarrega ao voltar do
  monitoramento, `estufa_resumo_card.dart`), e o teste de campo do mesmo dia
  mostrou a mesma família aparecendo em outro: depois de atualizar pelo QR Code,
  o segundo celular levou alguns segundos até aceitar comando.

  *Correção que mata a família toda:* a tela de monitoramento **lê a estufa do
  banco ao abrir**, em vez de confiar no que recebeu. Nenhum lugar da interface
  precisaria mais estar "em dia" com o banco.

  *Feito.* A tela relê a estufa no banco ao abrir
  (`credenciais_de_agora.dart`, 4 testes) e troca o monitor quando a cópia
  envelheceu — chave revogada, endereço editado ou aparelho reidentificado. Os
  quatro valores que vinham por cópia viraram estado da tela, alimentado pelo
  banco; a cópia recebida só serve para o primeiro quadro, para a tela continuar
  abrindo preenchida.

  A decisão ficou numa função separada da tela de propósito: montar
  `monitoramento_screen.dart` num teste exige Isar, preferências e rede, e o
  defeito não precisa da tela para ser provado.

  *O `aoVoltar` do `estufa_resumo_card.dart` fica.* Ele resolve outra metade: ao
  trocar o monitor, o card da home ainda segura a instância pausada, e é a
  recarga da lista que o devolve ao ar.

### 2.5 Aberto — achado em campo (12/08/2026)

- [x] **D2. O gráfico da estufada amassa tudo quando a secagem passa de um dia.**
  Visto no relatório de uma estufada de ~26h: leituras e pontos grudados,
  ilegíveis. O produtor perguntou se não seria o caso de recortar em 24h.

  *A causa não é o intervalo, é um teto.* `_larguraGraficoMobile()`
  (`grafico_estufada_card.dart`) calcula **120px a cada 10 minutos** — densidade
  correta — e termina em `largura.clamp(760.0, 1800.0)`. A estufada de 26h pede
  18.840px e recebe 1.800: dez vezes mais apertada do que a própria fórmula
  pediu. Estufada curta não encosta no teto, e por isso o defeito só aparece nas
  longas.

  *Duas correções foram tentadas e descartadas no aparelho*, e ficam registradas
  porque a segunda parecia certa no papel:

  1. **Só levantar o teto** (1800 → 6000px). Melhorava 3,3x e não resolvia: uma
     secagem de 100h continuava ilegível.
  2. **Zoom nativo do `fl_chart`** (`FlTransformationConfig`, pinça para
     aproximar), tirando o `_GraficoRolavelMobile`. Menos código e o produtor
     escolhendo a densidade — mas **reprovado no uso**: a pinça é mais
     trabalhosa que rolar, e os rótulos do eixo do tempo não reescalam junto,
     viravam um amontoado ilegível quando aproximado.

  *Feito.* **Janela padrão de 24h e densidade fixa de 2h por tela.** Sem filtro,
  o gráfico abre no último dia da estufada — ancorado no ÚLTIMO DADO, nunca no
  relógio, porque ancorar em "agora" já fez relatório de estufada encerrada abrir
  vazio. Com filtro, mostra o período pedido inteiro, na mesma densidade. O teto
  de largura sumiu: o que cresce com a secagem passou a ser quanto se arrasta,
  não quanto se espreme.

  O recorte se anuncia (*"Mostrando as últimas 24h"*) — recorte calado faria quem
  abre o relatório de uma secagem de quatro dias concluir que ela durou um.

  *De brinde:* o teste em tela estreita mostrou que a legenda do tracejado e a
  dica de arraste **estouravam a linha em 360dp**. Em release não aparece listra
  nenhuma; o texto era cortado calado. Os dois viraram `Flexible`.

### 2.6 Aberto — achado em campo (10/09/2026)

- [ ] **D3. O aparelho engasga: botões sem resposta e visor apagando por alguns
  segundos.** Relatado depois da montagem definitiva, em uso normal, *"não é no
  momento que clico várias vezes"*. Comandos e sensores funcionam; só a resposta
  local some e volta, e as leituras demoram a chegar ao app até um comando
  destravar.

  *A causa principal está confirmada no código.* `empurrarLeituraNuvem()`,
  `buscarComandosNuvem()` e `sincronizarChaveNuvem()` usam `HTTPClient` síncrono
  dentro do `loop()`. Enquanto a chamada não volta, nada mais roda: nem botões,
  nem visor, **nem o `server.handleClient()`** — por isso o app lendo pela rede
  local também fica sem resposta. O servidor é plano gratuito do Render.

  *O pior caso era de dois minutos, e não de segundos.* Nenhuma das três chamadas
  tinha prazo, e o aperto de mão TLS herdava o padrão do núcleo 3.2.0:
  `sslclient->handshake_timeout = 120000`. **O `http.setTimeout()` não alcança o
  aperto de mão** — ele vale para a leitura —, então consertar só o objeto HTTP
  teria deixado o pior caso intacto. Um diagnóstico externo chegou a propor
  exatamente isso.

  *Mitigado* em `180cb1b`: 4 s de aperto de mão, 3 s de conexão, 3 s de resposta,
  numa função só (`prepararConexaoNuvem`) pela qual os três clientes passam.
  Estourar o prazo não perde nada: a chamada se repete no ciclo seguinte, e a
  própria tentativa acorda o servidor.

  *Já estava mitigado, antes:* `48d2f7d` suspende o tráfego de rotina enquanto o
  produtor ajusta o alvo — emergência continua passando.

  *O que ainda NÃO está resolvido:* com o servidor acordado, cada chamada ainda
  leva 1 a 2 s — é o cálculo do TLS no próprio ESP32 —, a cada 20 s. **O conserto
  estrutural é mover a rede para uma tarefa do FreeRTOS no núcleo 0**, deixando o
  `loop()` livre no núcleo 1. O cuidado que ele exige é real: `temperaturaAlvoF`,
  `umidadeAlvo`, os carimbos de tempo, `buzzerTemperaturaAtivo` e `configSuja`
  passariam a ser escritos por duas tarefas, e sem mutex ou fila o sintoma troca
  de "trava perceptível" para **corrupção de dado esporádica** — mais rara e muito
  mais difícil de achar. **Decidido: depois da banca**, não antes.

  *Dúvida em aberto que decide o próximo passo.* "O visor apaga e volta ~2 s
  depois" não é o retrato de laço parado — com o laço parado, o TM1637 **congela no
  último quadro**, não apaga. É o retrato de reinício. `fc40bc5` passou a imprimir
  o motivo no boot e a expor `motivoReinicio` e `ligadoHaSegundos` no `/dados`,
  legíveis pelo navegador do celular em campo:

  | Motivo | Aponta para |
  |---|---|
  | `QUEDA DE TENSAO` | alimentação — cabo, fonte, pico da buzina somado ao Wi-Fi |
  | cão de guarda ou exceção | o firmware |
  | não reiniciou | era só o laço parado, já limitado pelos prazos |

  *De passagem, o servidor já se mantém acordado:* `keep_alive.js` pinga a própria
  URL pública a cada 10 min, abaixo dos 15 de hibernação. Se cold start continuar
  aparecendo, a primeira suspeita é esse mecanismo não estar pegando — não a falta
  dele.

### 2.7 Achado em campo (14/09/2026)

- [x] **D4. O relatório nunca trouxe o histórico da nuvem.** O PDF da estufada de
  12/09 22:30 a 14/09 08:11 (teste na outra casa) tinha leituras só nos horários
  de evento, e um buraco de 23:19 a 13:11 do dia seguinte. **A nuvem estava
  completa:** 232 leituras do `ESP32_215788` nessa janela, 6 por hora, a noite
  inteira, 231 delas com o relógio do aparelho certo. O defeito era do app, e
  eram dois, um escondendo o outro:

  1. **A precarga pulava a busca da nuvem.** Desde `b979f3a` (04/08) a tela de
     relatórios usa o relatório que o monitoramento adiantou — e a busca da
     nuvem só existia dentro da carga normal, que a precarga substituía. Pelo
     caminho de sempre (monitoramento, depois Relatórios, em até 3 min) a nuvem
     nem era chamada. Os consertos de 21/08 (`482aa20`, `45521a8`: id e chave do
     aparelho no pedido) estavam certos, mas num caminho que quase nunca rodava.
  2. **Com o celular no Wi-Fi da estufa, o pedido ia para o aparelho.**
     `buscarHistorico` usava a conexão ativa; em modo LOCAL ela é o ESP32, que
     não tem `/historico`: 404, lista vazia, **sem aviso nenhum**.

  *Por que ninguém viu antes:* os dois caem no mesmo lugar — o relatório com o
  que o celular gravou — e isso parece "o app ficou fechado". Só um teste longo,
  com o app fechado a noite toda, mostrou o tamanho do buraco.

  *Feito* em `87ec65f` (vai direto na nuvem; teste que reproduz o 404 do
  aparelho) e no commit seguinte da tela (a precarga passa por dentro da carga, e
  exportar espera a nuvem chegar em vez de gerar o arquivo sem ela). Junto:
  tabela do PDF com uma leitura por hora (`49b799b`) — com a nuvem, a estufada
  tem uma a cada 10 min —, CSV compartilhado como o PDF, e o texto do evento de
  desvio, que dizia "mais de 10°F" para um limite de 5°F (`b6003d6`). No mesmo
  dia o limite dos eventos passou a 8, o mesmo da sirene (ver `CONVENCOES.md`).

  *Não mudou:* o aparelho continua mandando a cada 10 min para a nuvem. Passar
  para 1 h foi considerado e descartado: é o que alimenta o gráfico e o
  acompanhamento de longe, e com a deduplicação na ingestão o banco guarda isso
  com folga (a cota de 500 MB está em `PLANO_BANCO_DADOS.md`). O afinamento é só
  no papel.

- [x] **D5. Depois de perder o Wi-Fi, o aparelho procurava a rede de fábrica.**
  `manterWifi()` reconectava com `WiFi.begin(WIFI_SSID, WIFI_PASS)` — as
  constantes do topo, `"SUA_REDE_WIFI"`, que desde `ab712ff` (20/07) são só o
  valor de fábrica. A rede configurada (`wifiSsid`/`wifiPass`, da NVS) ficou
  esquecida nesse caminho. Resultado: **uma queda de mais de 15 s** (roteador
  reiniciando) ou **uma primeira tentativa que não desse certo** no boot deixava
  o aparelho procurando uma rede que não existe, e o `begin()` ainda sobrescrevia
  a configuração da reconexão automática. Só voltava desligando e ligando.

  *Por que ninguém viu:* ligar e desligar usa o caminho do boot, que lê a rede
  certa. Os testes de queda de energia passaram por isso. Queda **só do
  roteador**, com o aparelho ligado, nunca foi testada.

  *De carona:* relógio (NTP), rede aprendida e IP fixo só eram feitos se a
  PRIMEIRA tentativa conectasse. Quando a rede aparecia depois, o relógio nunca
  era acertado e as leituras saíam com `millis()` no lugar da hora.

  *Feito (14/09):* reconecta na rede configurada; os passos de quem entrou na
  rede viraram `prepararRedeConectada()`, uma vez por boot, venha a conexão
  quando vier. E o aparelho passou a **guardar o motivo** que o rádio dá para
  cair ou não entrar, e a **mostrá-lo na página do modo de configuração** —
  "rede não encontrada (… só de 5 GHz)", "senha recusada (ou rede que pede
  usuário e senha)", etc. Foi o que faltou na faculdade (13/09): o Wi-Fi de lá
  não conectou e não havia como saber por quê.

  *Falta provar em campo:* desligar o roteador com o aparelho ligado, esperar
  1 min, religar — o aparelho tem que voltar sozinho.

- [x] **D6. No gráfico do relatório, trechos inteiros ficam sem bolinha.**
  Visto em 14/09 (print da umidade, janela das últimas 24h): a linha e o valor
  estão lá — arrastando o dedo aparece "Leitura 69% / Ajuste 70% / 13:03" —, mas
  telas inteiras não têm bolinha nenhuma, enquanto outras têm. Acontece na
  temperatura e na umidade.

  *Feito no mesmo dia, com a regra que o produtor escolheu:* bolinha na
  **primeira leitura de cada hora** (a mesma regra da tabela do PDF), em **toda
  leitura em desvio** e na última. No celular os horários do eixo passaram a ser
  **no máximo de hora em hora** (`intervaloRotuloMaximo`), e a margem vazia das
  pontas encolheu junto (era 1h06 de cada lado). Tela larga segue pela duração,
  porque mostra a janela inteira de uma vez. Dois testes em
  `grafico_estufada_test.dart`. O diagnóstico fica abaixo, como estava.

  *Causa provável, lida no código* (`grafico_steam.dart`, `_deveMostrarPonto`):
  a bolinha só aparece em três casos — leitura **fora da margem** (mais de 8 do
  ajuste), leitura perto do **primeiro ou do último** ponto, ou leitura perto de
  uma **marca do eixo do tempo** (a até ¼ do intervalo entre marcas).

  O intervalo entre marcas sai de `_intervaloParaDuracao()` sobre a **janela
  inteira com as margens**: 24h de leitura + 2 × 0,55 × 2h de margem = 26,2h,
  que cai na faixa "mais de 24h" → **marcas de 6 em 6 horas**. Então só ganham
  bolinha as leituras a até **1h30** de cada marca: 3h com bolinha, 3h sem, em
  ciclo. Só que desde o D2 cada tela mostra **2h** (`_horasPorTela`,
  `grafico_estufada_card.dart`) — então há telas inteiras dentro do trecho
  "sem", e é isso que se vê.

  A regra foi escrita quando a janela era fixa em 1h (marcas de 10 em 10 min, e
  quase toda leitura caía perto de uma). O D2 mudou a densidade da tela e a
  janela, e a regra das bolinhas ficou medindo a coisa antiga.

  *Por que parece aleatório:* as marcas contam a partir da **primeira leitura
  da janela** (`dadosMinX`), não da hora cheia, e a janela anda com o último
  dado. Abrir o mesmo relatório mais tarde muda quais trechos têm bolinha.

  *Caminhos para o conserto (escolher na hora):*
  1. Tirar o espaçamento das bolinhas da **densidade da tela** (2h por tela), e
     não da duração da janela — por exemplo, uma bolinha a cada 30 min.
  2. Bolinha em **toda leitura** que já sobreviveu ao afinamento
     (`_afinarPontos`, 5 min ou mudança de 5), já que a 2h por tela elas ficam a
     ~30 px uma da outra. É o mais simples; conferir se não polui.
  3. Bolinha nas **quinas do degrau** (onde o valor muda) mais as de sempre —
     mostra exatamente onde algo aconteceu.

  Conferir junto: o eixo do tempo usa o mesmo `intervaloRotuloMs` (6h), então
  numa tela de 2h pode não aparecer **nenhum horário** embaixo.

- [x] **D7. Os eventos de "ajuste alterado" só contam o que foi feito no app.**
  *Feito em 14/09, logo depois de achado:* o evento sai das **leituras**
  (`eventos_de_ajuste.dart`), que carregam o ajuste reportado pelo aparelho — a
  nuvem grava uma leitura sempre que ele muda. Uma linha por mudança, "alterado
  de X para Y", juntando o que acontece a menos de 5 min; ir e voltar ao mesmo
  valor não vira linha. O app parou de gravar o evento ao mandar o comando, e as
  estufadas antigas ganham a versão nova sem mexer no banco (os guardados são
  trocados na hora de mostrar). Rodado sobre o CSV real da #22: 13 linhas, onde o
  PDF tinha umas 30, e a mudança das 13:11 feita nos botões apareceu.

  *Achado no caminho:* o **CSV e o PDF exportavam a lista afinada do gráfico** —
  o CSV da #22 não tinha a leitura das 23:21 de 12/09, justo a que trazia o
  ajuste novo. Passaram a exportar a lista inteira.

  *O alarme com a sirene desligada* (a dúvida abaixo): era isso — o produtor
  tinha desligado o buzzer no aparelho, e o app e a nuvem gravavam o alarme pela
  **sirene**. Os dois passaram a gravar pela **condição** (`alertaTemperatura` ou
  fogo), como o push já fazia, e a linha do evento diz "(sirene desligada ou
  silenciada no aparelho)". Alarme com o app **fechado** continua sem linha de
  evento — os eventos são do app —, mas agora aparece na coluna "Alarme" das
  leituras, que vêm da nuvem.

  *O diagnóstico original, como estava:*
  Visto no relatório da estufada #22 (PDF de 14/09 10:36). Dois sintomas, uma
  causa:

  1. **Mudança feita nos botões do aparelho não vira evento.** As leituras
     mostram o ajuste de temperatura indo de 68 para 70 em 13/09 13:11, e não há
     linha de evento para isso.
  2. **Mexer no app com pausas vira uma rajada.** 13/09 14:12: "alterado para
     75°F", "76°F", "80°F", "85°F", e em 14:13 "80°F", "70°F". Às 18:43, cinco
     linhas no mesmo minuto.

  *Causa, lida no código:* o evento nasce em `_agendarEnvioTemperatura` /
  `_agendarEnvioUmidade` (`monitoramento_screen.dart`), isto é, **quando o app
  envia o comando** — um por pausa de 1 s do produtor. A mudança que chega pela
  leitura (feita no aparelho, ou por outro celular) abre a acomodação do detector
  (linha ~255) mas não registra evento. Contraria "o aparelho é a fonte da
  verdade": o relatório conta a história do app, não a da estufa.

  *Caminho para o conserto:* tirar o evento do envio do comando e derivá-lo do
  **ajuste que o aparelho reporta**, registrando quando o valor novo **para de
  mudar** (alguns segundos estável, e o aparelho fora de `modoAjuste`), como
  "alterado de 70 para 85°F". Cobre as duas origens e junta a rajada numa linha.

  *Junto, a verificar:* os eventos são gravados só pelo app aberto. Entre 13/09
  14:27 e 16:42 as leituras da nuvem dizem "Temperatura baixa" (10°F abaixo) com
  `alerta_incendio = 0` (é onde a nuvem guarda o alarme ativo), e o relatório
  não tem "Alarme acionado". Conferir se a sirene estava silenciada nesse
  intervalo; se não estava, o alarme não chegou à nuvem e isso é outro defeito.

  *Não é defeito:* os eventos antigos dizem "por mais de 10°F". O texto é gravado
  quando o evento acontece, e esses são de antes de 14/09; os novos dizem 8°F.

- [ ] **D8. Depois de sincronizar a fila, a tela mostra o ajuste antigo.**
  Visto no teste de 14/09 (registro em `RETOMADA_TCC.md`). Comando de 70°F
  pedido offline; ao religar o Wi-Fi o app entrou primeiro em NUVEM, mandou a
  fila por lá ("Aguardando a estufa aplicar", mostrando 70) e em seguida passou
  para LOCAL — mostrando **60**, o valor que o aparelho ainda tinha, sem aviso
  nenhum de comando a caminho. O produtor só viu 70 depois de mandar outro
  comando. O aparelho aplicou: a nuvem registra ajuste 70 às 11:03:47, e a foto
  do visor às 11:04:12 mostra 70.

  *Causa provável, lida no código:* a fila vai pela conexão ativa, e na volta
  do Wi-Fi a ativa era a nuvem; o aparelho só busca comando na nuvem a cada
  20 s (`COMANDOS_INTERVAL_MS`). No meio-tempo o app virou LOCAL e passou a
  mostrar o que o aparelho diz — verdade naquele instante, mas o aviso de
  "aguardando" só existe no modo nuvem (`aguardandoAparelho` vem do servidor), e
  o valor pendente já tinha sido apagado quando a leitura da nuvem o confirmou.

  *A conferir antes de consertar:* se a tela se corrige **sozinha** em até
  ~30 s (então é só o aviso que falta) ou se fica presa no 60 (então há outro
  defeito — a leitura local devia mostrar 70 no máximo 3 s depois do aparelho
  aplicar). Roteiro: repetir o teste e, ao voltar, **não tocar em nada** por
  1 min, olhando tela e visor.

  *Caminhos:* (1) ao sincronizar, se o aparelho responde na rede local, mandar
  a fila direto para ele — chega na hora; (2) guardar o valor sincronizado como
  pendente até o **aparelho** reportá-lo, com o mesmo aviso de "aguardando" em
  LOCAL.

### 2.3 Baixa — higiene

- [x] **C1. Ruído de log** (no servidor). *Feito: `estufa_server/log.js` com
  `LOG_LEVEL` (silencioso/erro/info/debug), 6 testes. Todos os 54 `console.*`
  do servidor migrados — não sobrou nenhum fora dos testes. A narração de ciclo
  do simulador virou `debug` e some em produção. Os 18 `debugPrint` do app
  ficaram: lá o Flutter já os descarta em release.*
- [x] **C2. `.g.dart` versionados** (≈8.500 linhas, 38% do app). É comum no
  ecossistema e a memória do projeto registra que regenerar já causou incidente —
  **manter versionado**. *Dito em `CONVENCOES.md`, com a regra que faltava:
  ao mexer numa entidade do Isar, regenerar e commitar junto — foi código
  gerado desatualizado que derrubou o app no boot.*
- [x] **C3. Documentação sem índice.** 21 arquivos em `docs/`, alguns já
  históricos. *Feito: `docs/README.md` separa o que vale hoje do que é registro
  do que já foi, e diz por onde começar conforme a intenção. Inclui a regra que
  faltava: quando documento e código discordam, **o código está certo** — e o
  documento virou dívida, a corrigir no mesmo commit.*

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

### Fase 4 — Decidir a arquitetura ✅
- [x] B3 registrar o destino e migrar por oportunidade
- [x] B5 web mantida por ora, com prazo para decidir
- [x] C2 registrar a decisão sobre `.g.dart`

### Fase 5 — Documentação ✅
- [x] C3 índice em `docs/`
- [x] Atualizar `HANDOFF.md` com o que esta auditoria mudou

---

**As cinco fases estão fechadas** (03/08/2026). O que a auditoria deixou em
aberto de propósito está declarado com prazo: a decisão sobre a plataforma web,
antes de começar a escrita do TCC.

---

## 5. O que esta auditoria NÃO cobriu

Honestidade sobre o alcance:

- **Não rodou o app em dispositivo** — a análise é estática mais o histórico de
  campo desta semana.
- **Não auditou o firmware linha a linha.** 1.992 linhas em um `.ino` único já é
  um achado por si (nenhuma separação em módulos), mas mexer nele exige o
  aparelho em mãos para validar, e ele está em produção.
- **Não mediu desempenho nem consumo de memória.**
