# Auditoria do Sentinela Smart

## D22 — identidade de 24 bits colidiu entre dois aparelhos (21/10/2026)

Dois ESP32 em propriedades diferentes se anunciaram como
`sentinela-215788.local`. O primeiro já havia registrado sua chave na nuvem; o
segundo recebeu `HTTP 401` tanto em `Chave -> nuvem` quanto em
`Push nuvem ->`, ficou apenas LOCAL, não enviou alertas push e seu QR foi
interpretado como atualização da estufa do primeiro aparelho.

A causa era o identificador usar somente os 24 bits finais do MAC. O firmware
agora usa os 48 bits (`ESP32_XXXXXXXXXXXX` e
`sentinela-xxxxxxxxxxxx.local`). O app reconhece exclusivamente a migração do
formato antigo para um MAC completo com o mesmo sufixo; qualquer outra troca de
ID continua bloqueada como outro aparelho.

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

### 2.6 Achado em campo (10/09/2026)

- [x] **D3. O aparelho engasga: botões sem resposta e visor apagando por alguns
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

  *Resolvido em 15/10/2026, antes da banca.* Com a ventoinha no aparelho o
  sintoma voltou a aparecer, e agora era visível sem precisar de app: os dois
  pontos do visor piscam quando a ventoinha está travada no botão, e eles
  paravam de piscar por 1 a 3 segundos em intervalos indeterminados — nesse
  tempo o aparelho não aceitava comando nenhum. Três consertos, nesta ordem:

  1. **A sonda não é mais esperada de pé.** `sensorTemp.setWaitForConversion(false)`:
     `lerSensores()` só pede a conversão, e `colherTemperaturaSePronta()` busca o
     valor 220 ms depois, em outra passada do laço. Antes, a leitura do DS18B20
     segurava o laço ~750 ms a cada 2,5 s — sozinha, isso já explicava um toque
     perdido.
  2. **O visor só é escrito quando muda.** Cada quadro do TM1637 custa dezenas de
     milissegundos de protocolo bit a bit, e o laço reescrevia o mesmo número
     milhares de vezes por minuto. Agora um cache (`ModoVisor`, `escreverNumero()`,
     `limparVisor()`, `escreverTracos()`) compara antes de falar com o display.
  3. **A rede saiu do laço de controle.** `tarefaNuvem()` roda no núcleo 0, criada
     com `xTaskCreatePinnedToCore(..., 12288, NULL, 1, NULL, 0)` — 12 KB de pilha
     porque o aperto de mão TLS é guloso e uma pilha curta reinicia o aparelho no
     meio da conexão. O laço fica no núcleo 1 com botões, sensores, relé, visor e
     `server.handleClient()`. Agora um servidor dormindo atrasa a nuvem, não o
     controle.

  *O cuidado que isto exigia, e como ficou resolvido.* O risco previsto era trocar
  "trava perceptível" por corrupção esporádica de dado. Dois pontos mereceram
  conserto de verdade:

  - **Memória permanente.** O objeto `Preferences` é um só, e dois núcleos
    abrindo-o ao mesmo tempo corrompem a partição. A tarefa de rede não grava
    nada: `marcarChaveRegistrada()`, o caminho do 401 e o do 409 apenas levantam
    `pedidoGravarChave`, e quem grava é `gravarPendenciasDeChave()`, chamada pelo
    laço. Todas as seis aberturas de `prefs` ficaram do lado do laço.
  - **O diário do `/log`.** Virou o único dado compartilhado de verdade: os dois
    núcleos escrevem com `registrar()` e o navegador lê em `handleLog()`. São
    objetos `String`, que realocam — uma escrita no meio de uma leitura entrega
    memória já liberada. Protegido por mutex (`trancaDiario`), com a leitura
    copiando tudo com a tranca na mão e respondendo depois.
  - **O resto é inteiro de 32 bits:** `temperaturaAlvoF`, `umidadeAlvo` e os
    carimbos de tempo. Escrita atômica no ESP32, e nenhum deles é lido em par com
    outro numa decisão. `configSuja` só é levantada pela tarefa e baixada pelo
    laço, nunca o contrário.

  A versão anterior está na etiqueta `firmware-pre-core0`, para voltar atrás sem
  arqueologia. Flash 88%, memória 15% — igual a antes.

  *Em campo, no mesmo dia:* os engasgos pararam. O conserto 2 trouxe um defeito
  próprio, corrigido em seguida — ver D12.

  *Situação em 14/09, com o firmware do dia:* o produtor não viu mais os
  engasgos feios. Sobra um toque de botão perdido de vez em quando ("clico 2 a 3
  vezes até responder"). Bate com o que resta do D3: a busca de comando na nuvem
  a cada 20 s ainda trava o laço 1–2 s, e um toque mais curto que isso, dado
  nesse intervalo, nunca é lido — algo como 1 toque em 10 a 20. Não é o botão.
  Conserto pequeno possível antes do núcleo separado: guardar o toque por
  interrupção (`attachInterrupt`) e tratá-lo quando o laço voltar. Decisão do
  produtor: aceitável por enquanto. **Dispensado:** com a rede fora do laço, o
  laço inteiro passa a rodar em milissegundos e não há mais janela onde o toque
  se perca.

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

  *Provado em campo em 14/09:* roteador desligado com o aparelho ligado. O
  aparelho seguiu lendo e mostrando no visor, o Serial deu o motivo na ordem
  certa — "sinal perdido (longe do roteador)" na queda, "rede não encontrada"
  com o roteador fora — e, religado o roteador, o aparelho voltou sozinho e o
  app reconectou sem ninguém mexer.

  *Ruído conhecido, inofensivo:* `E (…) wifi:sta is connecting, return error`
  a cada tentativa. É o `WiFi.begin()` do `manterWifi()` chegando enquanto a
  reconexão automática do próprio driver já está em curso; o driver responde
  "já estou conectando" e segue. Limpeza possível: só chamar `begin()` quando o
  driver não estiver tentando. Sem pressa.

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
  silenciada no aparelho)".

  *Alarme com o app fechado* (visto no mesmo dia: buzzer desligado, app
  fechado, a notificação chegou e o relatório seguiu em "3 alarmes"): passou a
  sair das leituras também (`eventos_de_alarme.dart`). A nuvem registrou o
  alarme às 14:02:06 com o buzzer desligado — a mudança do servidor já estava no
  ar. O relatório junta os eventos que o app gravou com os que as leituras
  mostram, sem repetir o mesmo episódio (5 min de tolerância). **Aprovado em
  campo em 14/09:** o alarme das 14:02, com app fechado e buzzer desligado,
  apareceu no relatório da #22. Limite: alarme
  mais curto que o intervalo entre duas leituras (uma por minuto na união com a
  nuvem) pode não aparecer.

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

- [x] **D8. Depois de sincronizar a fila, a tela mostra o ajuste antigo.**
  *Conferido, feito e aprovado em campo em 14/09* (refeito com o APK novo: a
  tela ficou no valor pedido, com o aviso, até o aparelho confirmar).
  Repetido às 13:39 (ajuste 65, pedido 60 sem
  internet): na volta a tela foi 60 → **65** → 60 sozinha em alguns segundos.
  Então era **só visual** — o comando sempre chegou. Conserto: a leitura da
  nuvem com comando ainda na fila (`aguardandoAparelho`) deixou de confirmar o
  valor pendente — só o aparelho confirma —, e depois de enviar a fila a tela
  segura o valor pedido com o aviso "Aguardando a estufa aplicar" em qualquer
  modo, até o aparelho reportá-lo ou vencer o prazo de 90 s (para um comando
  recusado não prender a tela). O caminho (1), mandar a fila direto ao aparelho
  quando ele está na rede local, ficou para depois: com o aviso, a espera de até
  20 s deixou de parecer defeito.
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

- [x] **D9. Encerrar a estufada gravava uma leitura zerada.** Visto no PDF da
  #22 encerrada (14/09 14:09): temperatura final **0°F**, umidade final **0%**,
  e três eventos inventados no fim — "ajuste alterado de 70 para 0°F", "de 65
  para 0%" e "Alarme normalizado" (o alarme ainda estava ligado). O CSV mostrava
  a linha: tudo zero, aviso vazio.

  *Causa:* ao encerrar, o evento de fim grava uma leitura com os valores da
  tela, e a tela ainda estava com os zeros de partida — nenhuma leitura do
  aparelho tinha chegado a ela. *Feito:* o app só grava leitura depois de
  receber uma de verdade (`_temLeituraReal`), e o relatório ignora as zeradas que
  já estão no banco do celular (`leitura_valida.dart`) — a #22 sai certa sem
  refazer nada. **Aprovado em 14/09:** o PDF da #22 gerado às 14:30 saiu com
  70°F / 65% finais e sem os eventos inventados; o CSV, sem a linha zerada.

- [x] **D10. Abrir o monitoramento sem conexão mostra 0°F / 0% e ajustes 0.**
  Visto em 15/09 13:07: celular sem Wi-Fi e sem dados, card da home em OFFLINE,
  e a tela da estufa abriu com tudo zerado. Não grava nada (o D9 barra), mas
  **os botões + e − ficam ativos**: um toque em + pediria ajuste de 1°F, que
  entraria na fila e seria aplicado pelo aparelho na volta da internet.

  *Consertado em 15/10/2026.* A tela passou a abrir com a **última leitura
  gravada no celular**, com um aviso cinza dizendo de quando ela é — o retrato
  velho deixou de se passar pelo agora. E os botões param quando não há base
  conhecida: sem leitura ao vivo e sem leitura guardada, o valor aparece como
  dois traços e o toque não manda nada. Ajustar sem internet continua valendo, que é
  proposital e o produtor usa; o que não pode é ajustar a partir de um número
  que o app inventou.

  *Causa:* a tela parte de zero e só troca ao receber a primeira leitura
  (`_temLeituraReal`); sem conexão, ela nunca chega. Quando a tela já estava
  aberta antes de cair (13:12), os valores ficaram certos.
  *Correção proposta:* desativar o `PainelControle` enquanto
  `!_temLeituraReal` e mostrar "—" no lugar dos zeros; melhor ainda, abrir com a
  última leitura salva no celular, marcada como antiga.

- [x] **D11. Eventos de dias diferentes aparecem só com a hora.** Na estufada 2
  (14/09 14:09 → 15/09) a lista mostra 19:02, 19:11, 08:00, 13:06… — parece fora
  de ordem, mas é a virada do dia.

  *Consertado em 15/10/2026* com a segunda opção: uma faixa discreta com a data
  a cada virada de dia, e só quando a lista atravessa mais de um dia — numa
  estufada de um dia só a data já está no cabeçalho da estufada selecionada.

### 2.8 Achado em campo (15/10/2026)

- [x] **D12. O visor apagava quando a ventoinha ligava e não voltava sozinho.**
  Apareceu no mesmo dia em que o cache do visor entrou (D3, conserto 2), e só
  nele: antes, o laço reescrevia o visor centenas de vezes por segundo, então
  qualquer quadro perdido se desenhava de novo em milissegundos e ninguém via.

  **O TM1637 não tem como ser consultado.** O cache guardava o que ele *acreditava*
  estar na tela e, se o display perdesse o quadro, nunca mais reescrevia — o
  visor ficava preto com o aparelho funcionando normalmente, o que o app
  confirmava mostrando tudo certo. **O sintoma que entregou essa parte:** apertar
  o botão da ventoinha trazia o visor de volta — não por reiniciar nada, mas
  porque trocar a trava muda os dois pontos, o cache vê diferença e reescreve.

  > **Correção de 16/10/2026 — a causa do quadro perdido NÃO era o contator.**
  > Este item atribuía a perda ao pico da bobina chaveando 220 V a centímetros
  > dos fios de dados. Era uma hipótese plausível e estava errada: o defeito é
  > **solda fria na placa**, e o produtor o reconheceu de quando a placa ainda
  > estava na caixa de papelão, **antes de o contator existir**. Ver D15.
  >
  > O que continua valendo deste item é a outra metade, que é a de software: um
  > cache sem caminho de cura deixava o visor preto para sempre depois de um
  > quadro perdido, qualquer que fosse o motivo da perda. O conserto está certo
  > e hoje ele cura as duas causas.

  *Conserto:* o quadro é reescrito do zero uma vez por segundo
  (`forcarReescritaVisor()`) e também no instante em que o relé troca de estado,
  que é quando o estrago acontece. Custa um quadro por segundo em vez de
  centenas — o ganho do cache fica de pé. A reescrita manda também o comando de
  brilho, que é o que reacende o display se ele perdeu essa parte.

  *O supressor do D13 continua valendo*, mas por outros motivos que não este —
  o pico da bobina é real mesmo quando não foi ele que apagou o visor.

  *De passagem,* `aplicarVentoinha()` passou a registrar no `/log` quando segura
  uma partida pelo prazo mínimo de 30 s. Era um `return` silencioso, e "o ajuste
  pede e ela não liga" tem quatro causas com o mesmo sintoma — prazo, trava no
  botão, fogo e falha de leitura. Agora o diário distingue.

- [x] **D13. Supressor na bobina do contator — instalado em 15/10/2026.**
  O conserto do D12 fez o aparelho se recuperar do distúrbio; **não o eliminou.**
  Em 15/10/2026, com o aparelho montado, o visor dá uma piscada visível a cada
  vez que o contator liga ou desliga. A piscada é o firmware reescrevendo a tela
  que acabou de ser derrubada — o pico da bobina continua saindo, a cada
  chaveamento, dentro de uma caixa fechada onde os cabos de 220 V passam a
  centímetros dos fios de dados.

  *Por que isto não pode ficar como está.* Hoje o estrago visível é cosmético.
  O que incomoda é o que não se vê: o mesmo pico atravessa o barramento OneWire
  do DS18B20, e leitura corrompida ali **para a ventoinha** (`leituraOk` falso
  zera `ledControleLigado`, de propósito). Pior caso conhecido do mesmo
  distúrbio: afundar os 5 V e reiniciar o ESP32 no meio de uma estufada.

  *O que fazer, em ordem:*
  1. **Supressor nos terminais A1/A2 da bobina** — 100 nF classe X2 275 VAC em
     série com 100 Ω / 1 W, ou varistor de 275 V. É o que mata o pico na origem,
     e resolve a maior parte sozinho. Detalhes e o que NÃO serve estão em
     `docs/MONTAGEM_DEFINITIVA.md`.
  2. **Afastar os quatro fios do visor** dos cabos de 220 V; onde cruzarem, que
     cruzem em ângulo reto, não lado a lado.
  3. **Capacitor de 100 µF na entrada de 5 V da placa**, se o caso for
     afundamento de tensão e não ruído.

  *Como distinguir ruído de afundamento, em campo:* se piscam só os dígitos, é
  ruído nos fios de dados — chato e inofensivo. Se os LEDs dão um tremido junto,
  ou se `/dados` mostra `ligadoHaSegundos` zerando ou `motivoReinicio` igual a
  `QUEDA DE TENSAO`, é a alimentação, e aí o item 3 entra junto.

  *Feito em 15/10/2026:* capacitor **0,1 µF X2 275 VAC MKP** (EN 60384-14,
  categoria climática 40/100/21) ligado em paralelo nos terminais **A1 e A2** da
  bobina, com as pernas estendidas por fio isolado para a rede — as pernas do
  capacitor são curtas demais para alcançar os dois parafusos. O resistor de
  100 Ω e o varistor são **alternativas ao par**, não complemento obrigatório; o
  trabalho principal está feito sem eles.

  *Ressalva honesta sobre a justificativa:* este item nasceu da piscada do visor
  a cada chaveamento, e **esse sintoma era solda fria** (D15), não o pico da
  bobina. O supressor continua certo pelos outros motivos — o pico existe, o
  barramento do DS18B20 passa perto e afundar os 5 V é o pior caso conhecido —,
  mas deixa de ter uma evidência de campo própria. Fica como prevenção, que é o
  que ele sempre foi para contator de 0,86 A.

### 2.9 Achado em campo (15/10/2026)

- [x] **D14. Wi-Fi travado só voltava tirando da tomada.** `manterWifi()`
  repetia `WiFi.begin()` a cada 15 s e nada mais. Isso recupera queda de sinal
  e **não** recupera rádio travado: sobre uma pilha que ficou num estado
  intermediário, `begin()` não faz nada, e o aparelho fica fora da rede até
  alguém desligar da tomada — com a estufa funcionando, mas sem app.

  *Conserto:* depois de 4 tentativas sem sucesso (1 min), o rádio é
  **desmontado e montado de novo** — `disconnect(true)`, `WIFI_OFF`, e na
  passada seguinte `WIFI_STA` + `begin()`. As duas metades ficam em passadas
  diferentes do laço de propósito: dormir entre elas pararia o controle. Se não
  voltar, repete a cada minuto, para sempre.

  *`ESP.restart()` não entra nesta escada, em nenhum degrau.* Decisão do
  produtor, e é a certa: reiniciar é **apagar o aparelho** — o visor morre, a
  sirene cala e o relé abre enquanto o chip sobe. Numa estufa com fogo aceso
  isso é pior do que ficar sem aplicativo. O termostato e o alarme são locais e
  seguem funcionando sem rede nenhuma; se o rádio não voltar, o aparelho
  continua cuidando da estufa e só o app se perde.

  *Para a investigação não depender de alguém estar olhando:* o contador de
  remontagens vive na memória permanente (`radioOff`) e aparece no `/dados`
  como `remontagensDoRadio`, junto de `segundosSemRede`. O `/log` é só RAM e
  morre no reinício — sem o contador, um aparelho que se recupera sozinho de
  madrugada não deixa rastro, e "parece que está bom" não se distingue de
  "aconteceu três vezes". **Número alto aí com `motivoReinicio` dizendo "ligado
  na energia" significa que o aparelho NÃO reiniciou: foi o rádio.**

### 2.10 Achado em campo (16/10/2026)

- [x] **D15. Solda fria na placa: o visor enfraquecia a qualquer trepidação.**
  Encontrado com a caixa aberta e o aparelho alimentado por power bank: **bater
  de leve em qualquer ponto da placa** fazia o visor quase apagar. Não era o
  cabo do visor — mexer nele não produzia nada.

  **A medida que separou as duas hipóteses:** `/dados` antes e depois do
  peteleco. O `ligadoHaSegundos` **continuou correndo**, ou seja, o ESP32 não
  reiniciou. Isso tira a alimentação de 5 V da lista e joga o defeito para
  depois do regulador — o barramento de 3V3 e o de terra da borda de baixo, que
  servem visor, DHT22, DS18B20 e sensor de chama, e não o ESP32.

  O sintoma era **enfraquecer**, não apagar: contato resistivo, não aberto. Por
  isso continuidade apitava e não acusava nada. O teste que acha isso é a
  **queda de tensão sob carga** — as duas pontas do multímetro nos dois lados da
  mesma ligação, com o aparelho ligado, pressionando a placa.

  *Conserto:* refundir. Resolvido — o visor parou de piscar.

  **Isto reescreve o D12.** O produtor reconheceu o defeito de quando a placa
  ainda estava na caixa de papelão, **antes de o contator existir**. A piscada
  no chaveamento, que o D12 atribuiu ao pico da bobina, era esta solda
  respondendo à vibração — e um contator de bobina CA vibra 120 vezes por
  segundo, dentro da mesma caixa, durante todas as horas em que a ventoinha
  roda. A caixa tinha uma fonte de peteleco permanente.

  *O que isso NÃO explica:* as quedas de Wi-Fi. Com o ESP32 sem reiniciar, o
  rádio travando é outro assunto, tratado no D14.

  *Efeito colateral do conserto do D12, que vale saber:* com o visor reescrito
  uma vez por segundo, uma solda marginal passa a aparecer como um tremido de
  menos de um segundo, em vez de tela preta. É resiliência, e também disfarce —
  um defeito de hardware nascendo fica menos visível. Vibração que faz o visor
  tremer merece multímetro, não paciência.

### 2.11 Achado na escrita do TCC (18/10/2026)

- [x] **D16. O texto do artigo e do resumo expandido subdeclarava a tese.**
  Na redação, "sem internet" virou sinônimo de "modo offline", e o modo offline
  é o terceiro caso: nem rede local, nem nuvem. O caso que o trabalho existe
  para provar — **rede local sem internet, lendo e comandando direto no
  aparelho** — aparecia como "o aplicativo continuou acessível pela rede
  local". Acessível não é comandar.

  **Não havia defeito no código.** `_postComFallback` manda o comando para a
  base devolvida por `_resolverBaseAtiva()`, que sonda as candidatas locais
  primeiro e só cai para a nuvem quando nenhuma responde; no firmware, o
  `POST /sincronizar` está no mesmo `WebServer` do `GET /dados`. A internet não
  entra nesse caminho. É o contrato que `docs/CONTRATO_API.md` já declarava.

  A evidência também já existia: a linha 1 de `docs/PLANO_POS_TESTES.md` se
  chama *"Operação local com a internet desligada — comandar e ler com o
  roteador sem link"*, aprovada em 14/09/2026.

  **O segundo erro era pior:** os trabalhos futuros prometiam "a entrega do
  comando diretamente ao controlador quando ambos estiverem na mesma rede, o
  que eliminaria a espera da consulta periódica". Isso **já está feito** desde
  sempre — é o que `_resolverBaseAtiva()` faz. A espera de ~20 s é só do
  caminho pela nuvem, onde o controlador busca os comandos. Oferecer como
  futuro o que já funciona entrega à banca uma pergunta de graça.

  *Conserto:* reescritos os dois documentos (Quadro de cenários, seção de
  resultados, considerações finais e conclusão). O item falso saiu dos
  trabalhos futuros e deu lugar à política de retenção do banco em nuvem, que
  é real e está no escopo.

  **Regra para a próxima revisão do texto:** antes de escrever "sem internet",
  dizer qual dos três estados — LOCAL (há Wi-Fi, não há internet), NUVEM (há
  internet, não há rede local) ou OFFLINE (não há nenhum dos dois). Os três se
  comportam de forma diferente, e trocá-los apaga ou infla o resultado.

### 2.12 Achado em campo (19/10/2026)

- [x] **D17. A estufa trocava de aparelho sozinha quando o endereço mudava
  de dono.**

  O aparelho de um parente foi ligado na rede do produtor para ser
  configurado, enquanto o aparelho do produtor estava **desligado**. O
  roteador entregou ao ESP32 novo o endereço que era do antigo — concessão
  vencida, endereço de volta ao bolo. A partir dali o app, falando com aquele
  endereço, recebeu outro `idHardware`, e a estufa cadastrada passou a apontar
  para o aparelho errado, carregando a chave de acesso do antigo. Sintoma
  final: comandos falhando por credencial, numa estufa que continuava com o
  nome certo na lista.

  **Não é defeito do firmware.** O `idHardware` e o nome mDNS saem do MAC do
  chip (`ESP32_xxxxxx`, `sentinela-xxxxxx`) e nunca repetem. O erro é de
  modelo, no app, em dois lugares:

  **Primeiro, a identidade era o endereço.** `EstufaEntity.chave` era
  `'<nome>::<ip>'`, num índice `unique: true, replace: true`. Endereço é
  emprestado pelo roteador; usá-lo como identidade significa que qualquer
  troca de concessão pode colidir, e o `replace: true` manda o Isar
  **substituir a linha existente em silêncio**. Agora a chave é
  `hw::<idHardware>` quando o aparelho já se apresentou, e `nome::ip` só para
  a linha que ainda não falou com nenhum aparelho.

  **Segundo, o identificador recebido vencia o cadastrado.** Em
  `AtualizacaoDeEstufa.entre()` estava `idHardwareNovo ?? idHardwareAtual` —
  bastava outro ESP32 atender no endereço para a estufa trocar de dono.
  Invertido: o cadastrado vence, e a estufa sem aparelho continua aprendendo o
  dela, que era a razão legítima daquela linha existir.

  Entrou também `_conferirDonoDaChave()`, que **recusa** gravar por cima de
  uma estufa de outro aparelho em vez de substituir, e um aviso na
  confirmação quando o endereço responde um aparelho diferente.

  *Correção relacionada:* `_idHerdado()` descartava o `idHardware` quando o
  endereço mudava, com o raciocínio de que "quem atender no endereço novo
  passa a valer". Era o avesso do que o cadastro precisa — endereço muda
  sozinho a cada concessão. Agora o identificador sobrevive à troca de
  endereço. Para repontar uma estufa de propósito: informar o id novo na
  edição, ou remover e cadastrar de novo.

  *Migração:* as chaves já gravadas são reescritas na abertura do banco, só
  quando a linha tem `idHardware` e o destino está livre. Nada é apagado, e
  duas linhas do mesmo aparelho ficam como estão — juntar sozinho escolheria
  qual histórico sobrevive, e essa escolha não é do app.

  *Teste:* `test/estufa_nao_troca_de_aparelho_test.dart`, quatro casos.

  **O que isto NÃO resolve:** ciclos, eventos e leituras continuam ligados à
  estufa **pelo IP**, não pelo aparelho. Então trocar de endereço ainda
  desgruda o histórico. É migração maior, de várias coleções, e fica
  registrada aqui como próxima.

### 2.13 Achado em campo (20/10/2026)

- [x] **D18. A estufa exibia o aparelho do vizinho, com selo LOCAL — e isso
  era regressão de um conserto nosso.**

  Aparelho do produtor **desligado**. O de um parente foi ligado na mesma rede
  e o roteador lhe deu o endereço que era do antigo. A estufa do produtor,
  cadastrada como `sentinela-215788.local`, passou a mostrar os números do
  aparelho do parente. Comandos falhavam por credencial.

  **O produtor disse a frase que resolveu o caso: "antes não era assim".**
  Era regressão, e o `git log` apontou qual: **`d29d37e` (15/10)**, *"Stop
  waiting on the slowest local probe"* — feito para atender outra queixa dele,
  a demora para conectar na rede local.

  Aquele commit trocou a sondagem **em ordem** por uma **corrida em paralelo**,
  onde ganha o primeiro endereço que responder. O comentário do código assumia
  que a ordem continuava protegendo (*"quando o IP muda, a sonda por IP falha e
  o nome ganha sozinho"*) — e isso só vale quando ninguém **atende** no IP
  velho. Com outro ESP32 segurando o endereço, ele responde primeiro e ganha,
  porque o nome mDNS do aparelho desligado não responde nunca.

  A guarda que existia (`_capturarIdHardwareLocal`) agia **tarde**: só depois
  de o endereço já ter virado a conexão ativa, e só quando a estufa tinha um
  `idHardware` gravado.

  *Conserto:* a verificação passou para a **sondagem**. Endereço cujo `/status`
  informa outro aparelho não vira conexão ativa — não há leitura para descartar
  depois, nem id errado para aprender. A corrida e a velocidade de `d29d37e`
  ficam de pé; só os candidatos errados são eliminados.

  *E uma defesa que não existia:* **o próprio endereço declara o dono.** O
  aparelho se anuncia como `sentinela-XXXXXX` e se identifica como
  `ESP32_XXXXXX` — os dois saem dos mesmos 6 hex do MAC. Então dá para saber
  qual aparelho é o certo **sem rede e sem nada gravado**, o que fecha o caso
  da estufa digitada à mão que nunca aprendeu o id.

  *Teste:* `test/endereco_nao_adota_outro_aparelho_test.dart`, quatro casos —
  inclusive o de que o aparelho **certo** continua conectando, porque conserto
  que derruba quem está certo não é conserto.

  **Lição de método, que vale mais que o conserto:** três perguntas minhas de
  diagnóstico não chegaram perto. O que localizou o defeito em um minuto foi o
  produtor dizer *"antes não era assim"* — e o `git log` do que mudou desde
  então. Comportamento novo em código estável é regressão até prova em
  contrário, e a primeira pergunta devia ter sido **"quando começou?"**.

### 2.14 Revisão de segurança e durabilidade (20/10/2026)

- [x] **D19. Registro concorrente podia autorizar uma chave que o banco não
  guardou.**

  O TOFU fazia `SELECT`, tentava `UPDATE` e, para aparelho ainda sem linha,
  executava `INSERT ... ON CONFLICT DO NOTHING`. Se duas chaves chegassem ao
  mesmo tempo, só uma entrava no banco, mas as duas requisições devolviam
  `registrada`. A rota então colocava a chave perdedora no cache de autorização,
  divergindo do PostgreSQL até o processo reiniciar.

  *Conserto:* o `INSERT` agora usa `RETURNING`; quando perde a corrida, o método
  relê a chave persistida e distingue `ja_registrada` de `conflito`. Só a chave
  que realmente venceu chega ao cache.

  *Testes:* dois casos em `test/db.test.js`, cobrindo concorrência com chave
  diferente e repetição concorrente da mesma chave.

- [x] **D20. A API confirmava comando remoto antes de ele estar durável.**

  A caixa colocava o comando no mapa, disparava a gravação no banco sem esperar
  e já respondia sucesso. Um reciclo do Render nesse intervalo perdia um ajuste
  que o app acreditava estar pendente. O agendador tinha a mesma janela e ainda
  removia o agendamento antes de saber se o comando fora guardado.

  *Conserto:* a persistência passou a ser aguardada. Falha devolve HTTP 503 e
  desfaz o comando em memória quando ele ainda é o vigente; comando concorrente
  mais novo não é apagado. O agendador também aguarda e só remove a origem após
  sucesso.

  *Testes:* a resposta espera o banco, falha não deixa comando buscável e
  agendamento não é removido quando a caixa falha. Servidor: **239 testes
  passando**.

### 2.15 Achado em campo (20/10/2026)

- [x] **D21. O fallback por IP do ESP32 apontava para a porta do servidor
  Node.**

  O aparelho informa `ipLocal` como `192.168.x.x` e serve HTTP na porta 80. A
  normalização genérica acrescentava porta 3000, adequada ao servidor local de
  desenvolvimento, mas inexistente no ESP32. Quando o mDNS `.local` oscilava,
  a suposta segunda porta tentava `192.168.x.x:3000`, falhava junto e fazia o
  selo alternar LOCAL → NUVEM → OFFLINE mesmo com celular e aparelho no mesmo
  Wi-Fi.

  *Conserto:* endereço aprendido do aparelho usa porta 80; uma porta informada
  explicitamente continua sendo respeitada. A checagem de `idHardware` segue em
  todas as candidatas, então dois aparelhos na mesma rede não misturam dados
  mesmo se o roteador reutilizar um IP antigo.

  **Confirmado em campo em 21/10/2026**, com o APK corrigido instalado: o selo
  para de alternar e fica em LOCAL. A verificação é deixar o celular **parado**
  na tela da estufa — mexer no aparelho mantém o tráfego acordado e esconde o
  defeito, que foi o que atrasou o diagnóstico.

  **Hipótese errada que este achado derrubou:** o mesmo sintoma levou a
  desligar a economia de energia do rádio no firmware (`WiFi.setSleep(false)`,
  20/10). A mudança é boa e ficou, mas não era a causa — e a entrada dela no
  `HISTORICO_FIRMWARE.md` foi corrigida para dizer isso, senão quem lesse
  depois herdaria a explicação errada junto com o conserto certo.

  *Teste:* `test/resolucao_conexao_test.dart` agora derruba o mDNS, só deixa o
  IP responder na porta 80 e confirma LOCAL; há também cobertura para porta
  explícita. App: `flutter analyze` limpo e **219 testes passando**. APKs
  completo e TCC foram gerados com a URL da nuvem e validados pelo build.

### 2.16 Achado em campo (21/10/2026)

- [x] **D22. Um ajuste de 55 °F nos botões parou TODA a telemetria por 14
  horas, com a rede perfeita.**

  Sintoma: o produtor foi à cidade e a nuvem não mostrava nada. O app dizia
  *"Aparelho sem comunicação há 14h 24min"*, e ao mesmo tempo *"Servidor na
  nuvem: disponível"*. O local funcionava.

  **A prova veio do diário do próprio aparelho**, alcançado pela rede local:

  ```
  15405s  Push nuvem -> HTTP 400
  15466s  Push nuvem -> HTTP 400
  ```

  `400`, não `401` nem `-1`: o aparelho **alcança** o servidor e o servidor
  **recusa o conteúdo**. O `/dados` confirmou que a rede estava impecável —
  `segundosSemRede: 0`, `remontagensDoRadio: 0` — e entregou o culpado:
  `"temperaturaAlvoF": 55`.

  **A causa:** `definirTemperaturaAlvo()` limitava só o **teto**
  (`ALVO_MAXIMO_F = 165`) e nunca o **piso**. O servidor recusa abaixo de 60
  (`LIMITE_TEMPERATURA_MIN`, em `sync.js` e `agendamentos.js`) e o aplicativo
  também não oferece menos (`ajusteTemperaturaMinimoF`). Só o aparelho ficou
  fora do contrato — o espelho exato do que aconteceu com o teto de 165, que
  foi corrigido nos três lugares em 16/10. O piso nunca foi feito.

  **O que torna isto grave não é o comando recusado — é o raio do estrago.** O
  envio de leitura leva a configuração vigente junto, então um único campo fora
  da faixa faz o servidor descartar **a leitura inteira**, a cada minuto, em
  silêncio. Perde-se temperatura, umidade, alarme e histórico — tudo por causa
  de um número que nem é medição. E, visto de fora, parece falta de internet.

  *Conserto:* `ALVO_MINIMO_F = 60`, aplicado no mesmo ponto e pelo mesmo motivo
  do teto — *"aqui passa tudo: os botões do aparelho, o comando vindo da nuvem e
  o que a sincronização traz de volta"*.

  *Desbloqueio sem gravar nada:* subir o ajuste para 60 °F pelos botões faz o
  envio voltar no ciclo seguinte.

  **Aberto, e maior que este conserto:** validar configuração junto com
  telemetria faz um erro de configuração apagar medição. O servidor está certo
  em recusar payload inválido, mas o preço é desproporcional e mudo. Vale
  separar: recusar o campo de configuração e **ainda assim gravar a leitura**,
  ou ao menos registrar no servidor por que a recusa aconteceu — hoje o 400 só
  aparece no diário do aparelho, se alguém for olhar.

  **Lição de método:** o diagnóstico levou minutos porque o aparelho registra o
  que acontece quando ninguém está olhando, e porque `heapMinimo` e
  `pilhaNuvemLivre` existiam para descartar memória e pilha de cara. Os dois
  entraram ontem. Instrumento vale mais que palpite.

### 2.17 Achado em campo (25/10/2026)

- [x] **D23. Dois toques seguidos no botão preto travam o aparelho, e só a
  tomada o traz de volta.**

  Sintoma, relatado pelo produtor: o botão preto "às vezes não funciona". O
  verde e o vermelho seguem respondendo, e **os dois pontos do visor param de
  piscar** quando o preto é apertado mais de uma vez. Tirar e recolocar na
  tomada resolve.

  **O que os três fatos juntos provam.** Pontos parados = o laço de controle
  morreu, não está apenas ocupado. Verde e vermelho funcionando = o problema
  não é o laço em geral, é o que **aquele** botão dispara. Voltar só pela
  tomada = travamento, não reinício: um *reset* se recuperaria sozinho.

  **A causa.** O botão preto é o único que mexe no relé — o verde troca o que o
  visor mostra, o vermelho abre o ajuste. Cada toque inverte a trava da
  ventoinha, então dois toques em poucos segundos **abrem e fecham o contator**:
  duas partidas de um motor de 1 a 3 CV a centímetros da placa, com corrente de
  partida de 5 a 7 vezes a nominal. O transitório trava o ESP32.

  O firmware já registrava a vizinhança disso, em `aplicarVentoinha()`, logo
  após o `digitalWrite` do relé: *"o chaveamento é o momento em que o visor
  costuma perder o quadro"*. O visor perdendo o quadro é a versão leve do mesmo
  transitório; o travamento é a versão grave.

  **De onde veio.** Em 21/10 o prazo de 30 s entre partidas foi removido a
  pedido do produtor — a histerese já atrasa o religamento, e o prazo só adiava
  o que ele acabara de mandar pelo botão. O `HISTORICO_FIRMWARE.md` registrou o
  risco na mesma entrada: *"se o contator começar a bater seguido, é aqui que se
  volta, e um prazo curto de uns 5 s cortaria a batida sem o atraso"*. O caso
  previsto era a temperatura parada na fronteira da histerese. O que aconteceu
  foi mais direto: o próprio produtor produz a batida apertando o botão duas
  vezes.

  *Conserto:* `ESPERA_ENTRE_PARTIDAS_MS = 5000`, só no sentido de **ligar**.
  Desligar nunca espera — fogo, temperatura acima do teto e sensor mudo são o
  lado da segurança e não podem entrar em fila. Sem estado novo: a volta
  seguinte do laço tenta de novo e a ventoinha parte sozinha quando o prazo
  vence.

  **Aberto, e maior que este conserto:** o prazo impede a batida rápida, não o
  transitório. Uma partida isolada continua produzindo o mesmo pico, e o visor
  continua perdendo o quadro — por isso a reescrita forçada existe. Vale olhar o
  hardware: distância entre a fiação de 220 V e a placa, e a alimentação do
  ESP32. O supressor instalado em 15/10 está na **bobina do contator**; a
  partida do **motor** é outro evento, bem maior.

  **Lição de método:** a pergunta que resolveu foi *"os dois pontos ainda
  piscam?"*. Três observações do produtor — pontos parados, outros botões vivos,
  volta só pela tomada — fecharam o diagnóstico antes de qualquer leitura de
  código. E o conserto estava escrito no histórico havia quatro dias, por quem
  removeu a proteção.

### 2.18 Pedido do produtor (28/10/2026)

- [x] **D24. O modo de configuração dependia do botão menos confiável do
  aparelho.**

  Pedido do produtor, com o motivo: *"o botão do buzzer não responde direito"*.
  Entrar no modo de configuração exigia os **três** botões, e um deles é o preto
  — o mesmo que o D23 mostrou ser o que mexe no relé, e que ele já vinha
  descrevendo como intermitente.

  **Por que isso é pior do que parece.** O gesto não dava retorno sobre *qual*
  parte falhou. Segurar os 3 s e não acontecer nada era indistinguível de errar
  o gesto, e a única saída era tentar de novo — na frente da estufa, com o
  celular na mão esperando a rede `Sentinela-Config` aparecer. Uma prova de
  presença física não deveria depender do botão de pior contato.

  *Conserto:* a combinação passa a ser **verde + vermelho por 3 s**. Segurar os
  três continua abrindo, porque verde e vermelho estão entre eles — quem
  aprendeu o gesto antigo não fica de fora, e não houve o que desaprender.

  **O que o conserto trouxe de novo, e precisou ser tratado.** Verde e vermelho
  *são* os botões de ajuste de alvo. Apertar dois botões nunca é simultâneo, e o
  primeiro a fechar contato mexe no alvo antes de existir combinação nenhuma —
  o que era acidente de borda com os três botões passou a acontecer em **toda**
  tentativa. O descarte já existia ao entrar no modo (recarregar os alvos da
  NVS), mas não cobria dois caminhos:

  1. **A gravação podia acontecer durante a contagem.** `salvarConfigSeNecessario()`
     grava 1,5 s depois da última mudança — ou seja, no meio dos 3 s do gesto.
     O descarte então releria da NVS exatamente o acidente que queria jogar
     fora. Agora a gravação fica suspensa enquanto a combinação conta.
  2. **Desistir no meio não descartava nada.** Quem solta antes dos 3 s nunca
     passa por `entrarModoConfig()`, e o alvo ficava com o toque que abriu o
     gesto. Agora soltar antes do tempo chama o mesmo descarte.

  O descarte voltou a ler também os **carimbos de tempo** (`tempTs`/`umidTs`), e
  não só os valores: sem isso o alvo antigo voltava com a hora do toque
  acidental e venceria, no *Last-Writer-Wins*, um comando remoto legítimo mais
  velho que o toque — mas mais novo que o alvo que estava voltando.

  **Onde mais mudou:** as quatro instruções da tela de configuração do app, que
  mandavam segurar três botões, e `CONFIGURACAO_ESP32.md`, `MAPA_DO_CODIGO.md`,
  `HANDOFF.md`, `ROTEIRO_BANCA.md` e `SEGURANCA_COMANDOS.md`. Documento que
  ensina um gesto que o firmware não aceita mais é pior que documento nenhum.

  **Não mudou:** sair do modo continua sendo **qualquer** botão por 1,5 s (o
  preto só adiciona uma saída, nunca tira), e segurar **só** o preto por 3 s
  continua ligando e desligando a sirene de temperatura.

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
