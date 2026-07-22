# Viabilidade comercial: nuvem, custo e a promessa vitalícia

Discussão iniciada pelo autor em jul/2026, pensando na venda do aparelho + app em
escala (potencialmente milhares de unidades e produtores simultâneos).

> **Escopo:** isto está **além do TCC**. A arquitetura atual (Render + Supabase +
> FCM, planos grátis) é ótima para o trabalho e prova o conceito. Este documento
> é planejamento de **produto**, e daria uma boa seção de "trabalhos futuros /
> viabilidade comercial" no artigo.

**As seções são análise técnica (do assistente) sobre o problema colocado pelo
autor. Não são decisões tomadas** — o autor ainda vai trazer ideias próprias.

---

## 1. O problema, nas palavras do autor

- A venda pode chegar a **milhares de unidades** usando app e aparelho ao mesmo
  tempo;
- O produtor rural quer algo **vitalício** — comprou, é dele, não quer
  mensalidade;
- O autor **também não quer pagar assinatura para sempre** para manter o serviço;
- Os planos grátis de **Render, Supabase e Firebase** não aguentam essa escala.

**O medo é duplo e explícito:** (a) o custo mensal que sairia do bolso do autor,
e (b) a promessa de "vitalício" que ele precisa conseguir cumprir para vender.
Ambos pesam igual.

---

## 2. A verdade estrutural

**"Vitalício" e "serviço de nuvem sempre ligado" são incompatíveis por
natureza.** Um servidor 24h custa dinheiro todo mês, para sempre. Se o produtor
paga uma vez e usa por 10 anos, alguém banca 10 anos de servidor — o autor, ou o
serviço morre. Não existe nuvem grátis eterna; existe nuvem que *alguém* paga.

Logo, o erro seria prometer "nuvem vitalícia grátis". A saída **não** é achar um
plano grátis que aguente a escala — é mudar a arquitetura para que **o custo pare
de crescer com o número de aparelhos**.

---

## 3. O que já protege o projeto: edge-first

O sistema é **edge-first** — o aparelho é a fonte da verdade e **funciona sem
nuvem** na rede local. Isso permite separar o produto em duas camadas com
naturezas diferentes:

| Camada | Custo para o autor | Promessa honesta ao produtor |
|---|---|---|
| **Monitorar/controlar na propriedade** (aparelho + app no mesmo Wi-Fi) | **Zero** — nenhum servidor | **Vitalício de verdade** — funciona para sempre |
| **Acesso remoto + histórico + push** | Custo mensal real | Isso é um **serviço** |

O produto comprado é do produtor para sempre. O que roda pela internet é serviço.
E a maioria dos produtores está **na propriedade** quando a estufa cura — o
remoto é conveniência, não o essencial. Isso sustenta a promessa vitalícia sem
mentir.

---

## 4. O ponto técnico que decide o custo

Um **simulador só** já estourou os 500 MB do Supabase (ver
`PLANO_BANCO_DADOS.md`). Mil aparelhos a 1 leitura/min = **~1,4 milhão de linhas
por dia**. Qualquer plano grátis morre em dias; qualquer plano pago vira conta
que cresce sem parar.

**A raiz é usar a nuvem como banco de histórico.** O custo que escala com o
número de aparelhos é o **banco de dados**. Correção:

- **Tirar o histórico da nuvem.** Ele já pode viver onde não custa nada: no
  **aparelho** (fonte da verdade — precisaria de cartão SD) e no **celular** (o
  Isar já guarda por estufada — isso já existe);
- **A nuvem vira um relé burro:** valor atual, repasse de comando, gatilho de
  push. Quase sem armazenamento. Um relé que não guarda nada **não cresce** — o
  custo é o mesmo com 10 ou 10.000 aparelhos.

**Resultado: o custo descola do número de unidades.** Deixa de ser "quanto mais
vendo, mais pago" e vira um valor fixo pequeno. Este é o ponto central de tudo.

---

## 5. Boas notícias concretas

- **FCM (push) é grátis em qualquer escala.** O Firebase não cobra por mensagem
  nem por aparelho. A peça mais assustadora é a que escala de graça — **pode
  manter**. Os limites que existem são **técnicos, não de cobrança**, e o projeto
  não encosta neles: 4 KB por mensagem (o alerta são bytes), anti-spam por
  aparelho (o envio é ocasional), cota de API altíssima.

  **Mas "Firebase" não é uma coisa só — só o FCM é ilimitado.** Outros serviços
  têm teto no plano grátis (Spark), e um deles é justo o candidato a relé:

  | Serviço Firebase | Grátis (Spark) |
  |---|---|
  | **Cloud Messaging (FCM)** — em uso hoje | **sem limite prático** |
  | **Realtime Database** — se virar relé | ~100 conexões, 1 GB, 10 GB/mês |
  | Firestore | ~50 mil leituras/dia, 20 mil escritas/dia |
  | Cloud Functions | 2 mi execuções/mês (exige plano Blaze ativo) |

  Não confundir "uso o Firebase e é grátis" com "tudo no Firebase é ilimitado":
  se o relé for o Realtime Database, herda o teto de ~100 conexões (7.10), **não**
  a liberdade do push. E ativar o **Blaze** (pague-conforme-usa) mantém o FCM
  grátis, mas passa a **cobrar** os outros serviços após a cota — uma função em
  loop poderia gerar conta. Enquanto for só FCM, nada disso toca o projeto;
- **O relé, sendo leve, é barato.** **MQTT** é feito para milhares de aparelhos
  pequenos com mensagens minúsculas; roda num **VPS de ~US$ 5/mês** aguentando
  **milhares** de conexões. Substituiria o Render, cujo modelo HTTP+polling é
  pesado e ainda dorme no grátis;
- **Render e Supabase grátis foram perfeitos para o TCC**, mas nenhum é feito
  para produção. Trocá-los é a graduação natural do projeto, não um fracasso.

---

## 6. Modelos para bancar o relé sem assinatura eterna do autor

Com a nuvem virando relé barato de custo fixo, três modelos ficam viáveis (dá
para combinar):

1. **Margem do hardware paga o relé.** Custo de nuvem por aparelho quase zero
   (relé + FCM, sem banco) → alguns reais no preço de venda cobrem anos de
   operação. Comunicado como "nuvem inclusa";
2. **Remoto como opcional pago.** Quem quer ver de longe assina barato; quem fica
   na propriedade usa tudo localmente de graça. Alinha quem gera custo com quem
   paga;
3. **Honestidade de prazo.** "Acesso remoto garantido por X anos" em vez de
   "vitalício" — mais verdadeiro, evita a promessa que quebra.

**A evitar:** escalar o modelo atual (banco na nuvem + servidor sempre ligado
guardando tudo) para produção. É o único que faz o autor pagar cada vez mais
conforme vende mais.

---

## 6b. Precedente de indústria: o P2P do CFTV (ex.: iSIC/Intelbras) **[análise]**

O relé que a gente desenhou **não é invenção nova** — é o mesmo padrão que todo
sistema de câmera de consumidor usa para "ver pela internet". Bom para justificar
a arquitetura no TCC. (Descrição do **mecanismo geral** desses sistemas; não são
detalhes internos específicos do produto da Intelbras.)

| CFTV (P2P) | Este projeto |
|---|---|
| Modo local por IP na mesma rede | Modo `LOCAL` |
| Servidor P2P de encontro (nuvem do fabricante) | O "relé mínimo" (seção 5–6) |
| Número de série do DVR | `idHardware` |
| DVR faz conexão de **saída** e se registra | O hub mantém túnel de saída |

Como funciona o remoto: o aparelho, ao ligar, abre conexão de saída para o
servidor do fabricante e se registra pelo número de série; o celular pergunta ao
servidor "onde está o aparelho X?"; o servidor **apresenta os dois lados**. Daí:

- **Hole punching:** o servidor só apresenta e o tráfego flui **direto** entre
  celular e aparelho — economiza banda do fabricante (por isso é barato manter);
- **Relay (fallback):** quando o furo de NAT falha (CGNAT dos dois lados), o
  tráfego passa **pelo servidor** — custa banda, e é por isso que planos grátis
  às vezes limitam o remoto.

**As duas lições:**

1. **Alguém paga o relé** — o fabricante paga, embutido no preço e no porte da
   empresa. Confirma a seção 6;
2. **O nosso é muito mais barato que o deles.** Câmera transmite **vídeo** (banda
   pesada); este projeto manda **leituras minúsculas de sensor**. Se um
   fabricante oferece vídeo remoto de graça e "vitalício", um sistema que move
   mil vezes menos dados banca o seu relezinho com folga enorme. O problema mais
   difícil dessa família (vídeo) já é resolvido a preço de consumidor — o nosso é
   a versão leve.

---

## 7. Arquitetura de hub local (convergência da conversa)

Ideia trazida pelo **autor** e lapidada em conjunto: um **segundo ESP32 na
residência** faz o papel de hub/servidor local. As estufas conversam com o hub;
o celular conversa com o hub; o hub tem cartão SD e acesso à internet.

### 7.1 O desenho que fechou

```
  Estufa 1 ]                                                    [ Celular
  Estufa 2 ]--- ESP-NOW (perto) / LoRa (longe) ---[ HUB ]--- Wi-Fi local
  Estufa 3 ]                                       (casa)         |
                                                     |            | (fora)
                                                   SD +           |
                                                 internet         v
                                                     |      [ relé mínimo
                                                     +----->  MQTT + FCM ]
                                                              (nuvem stateless)
```

- **Celular ↔ hub:** sempre **Wi-Fi normal**. O celular **nunca** fala ESP-NOW
  nem LoRa — quem faz essa ponte é o hub. Modelo mental único: o celular só
  conhece o hub; o hub varia o rádio conforme a distância da estufa;
- **Hub ↔ estufas:** Wi-Fi (perto), **ESP-NOW** (curto alcance real — ver 7.6),
  **LoRa** (centenas de m a km);
- **Histórico:** no **cartão SD do hub** (não no celular). O hub fica ligado 24h
  na tomada, então coleta sem gastar bateria de ninguém;
- **Remoto:** o hub mantém uma conexão de saída com um **relé mínimo** na nuvem;
  o **push (FCM)** cobre o caso crítico de graça.

### 7.2 Decisões do autor (contexto real)

- **LoRa** interessa para estufa **longe na lavoura**. Vira **produto à parte /
  pacote mais caro (encomenda)**, não o básico;
- **ESP-NOW** é o caminho a seguir para os galpões próximos (mas o alcance real
  com paredes é bem menor que os 200 m de folheto — ver 7.6);
- **Wi-Fi** é o que já existe hoje;
- **Remoto é ocasional:** o produtor fica em casa, perto, ou na lavoura. A nuvem
  só entra quando ele vai à cidade ou passa o fim de semana fora;
- **ESP vs Pi:** indefinido. Medo declarado: guardar histórico/relatórios no
  celular consumir bateria e memória.

### 7.3 Como cada dúvida do autor se resolveu **[análise]**

**"Como o celular fala com o LoRa na lavoura?"** — Ele não fala. Três casos:
1. Em casa/perto do hub: celular→hub (Wi-Fi), hub→estufa distante (LoRa);
2. Do lado da estufa: os **botões e o visor da própria estufa** já bastam
   (edge-first);
3. Andando pela lavoura, longe do hub **e** da estufa, querendo o celular: aí
   sim um **bridge portátil** (ESP+LoRa de bolso, LoRa↔Bluetooth/Wi-Fi). É
   acessório do "pacote melhor" — só este caso pede hardware novo.

**Medo de bateria/memória do celular** — infundado pelos números:

| | |
|---|---|
| Leitura guardada | ~100 bytes |
| Amostragem (política atual) | 1 / 10 min + eventos |
| Uma estufada (~6 dias) | ~1.000 leituras = **~100 KB** |
| Comparação | uma foto tem 3.000–5.000 KB |

Anos de relatórios = poucos MB. E o **hub** é quem coleta 24h (na tomada); o
celular só **puxa uma cópia leve ao abrir o app**, então não drena bateria. O
hub tira do celular exatamente a carga temida — é o argumento mais forte **a
favor** de ter hub.

**Remoto ocasional é boa notícia de custo** — o caso crítico ("estou na cidade e
pegou fogo") é **push, e push é grátis**. O relé pago serve só para a curiosidade
de abrir o app de longe: raro e leve, cabe em VPS de ~US$ 5 servindo milhares, ou
até em camada gratuita.

### 7.4 ESP32 ou Pi como hub **[análise]**

Armazenamento **saiu da disputa** (100 KB/estufada cabe num SD de qualquer ESP,
anos de histórico). O que pesa é **quem faz push e relé**. Arranjo que dissolve a
escolha:

- **Hub burro e barato (ESP32):** conversa com as estufas, grava no SD, mantém
  conexão de saída com o broker MQTT. Só isso;
- **Parte esperta, sem estado, na nuvem:** broker MQTT barato + função grátis que
  dispara o **FCM** (assinar token do FCM é pesado demais para um ESP32 fazer
  sozinho — melhor deixar na nuvem).

**Recomendação: começar com ESP32 como hub** (barato, terreno conhecido do
autor). Pi vira opcional, só se um dia o hub precisar fazer tudo sozinho.

**Ressalva honesta:** SD em ESP32 **corrompe se a energia cai no meio de uma
escrita** — e queda de luz é o cenário-título. Tratar com escrita segura e talvez
um **capacitor** que segura energia o tempo de fechar o arquivo.

### 7.5 Alcance real do ESP-NOW **[análise]**

Os **~200 m são campo aberto, antena com antena, sem obstáculo** — o melhor caso
de folheto. O ambiente real é o pior possível para os 2,4 GHz que o ESP-NOW usa,
porque essa frequência (a mesma do micro-ondas) é **absorvida pela água** e
barrada por alvenaria e metal:

- parede da casa (hub dentro) na saída;
- pátio/lavoura no meio;
- estrutura do galpão (metal/alvenaria);
- **a massa de fumo molhado** dentro do galpão — uma esponja de água justamente
  na frequência que a água mais absorve.

Na prática, hub dentro de casa e galpão do outro lado, os 200 m viram
facilmente **30–80 m**, e podem ficar instáveis. **Só o teste na propriedade real
diz a verdade.**

O que mais ajuda, em ordem de impacto:

1. **Antena externa no hub** (ESP32 com conector u.FL), montada **fora da casa**,
   virada para os galpões — tira a parede da frente. Maior alavanca isolada;
2. Hub perto de uma **janela** que enxergue os galpões;
3. **Repetidor** ESP-NOW no meio do caminho.

**Consequência para o produto:** se a propriedade tem parede e distância no
caminho, o **LoRa deixa de ser "premium" e vira a escolha certa** — é sub-GHz
(915 MHz), atravessa obstáculo muito melhor. Talvez o ESP-NOW só sirva para
galpão colado na casa, e o LoRa seja o padrão. O teste em campo decide.

### 7.6 Proteção do SD contra queda de energia **[análise]**

**Não é bateria, e não se mede em mAh.** Terminar uma gravação e fechar o arquivo
leva de alguns ms a ~1 s. No pico da escrita o ESP puxa ~250 mA. Energia:

> 250 mA × 1 s = **~0,07 mAh**

Menos de um décimo de mAh. Bateria seria absurdamente superdimensionada, e ainda
**envelhece** (isso dispara a cada queda de luz, por anos). O componente certo é
um **supercapacitor**:

| Opção | Segura por | Veredito |
|---|---|---|
| Eletrolítico 4.700 µF | ~30 ms | marginal — só um flush |
| **Supercap 1 F / 5,5 V** | **1–3 s** | **folgado, fecha o arquivo com sobra** |

Custa poucos reais, dura a vida do produto sem envelhecer. Liga com **um diodo**
entre a fonte e o ESP, para o capacitor alimentar o ESP na queda sem empurrar
energia de volta para a fonte morta.

**Mas o capacitor é a parte fácil. O trabalho real é o firmware:**

1. **Detectar a queda** — divisor de tensão na entrada avisando um pino (o ESP32
   tem detector de *brownout* embutido);
2. Ao detectar, **fechar o arquivo na hora** e marcar "desligamento limpo";
3. **Gravar sempre de forma segura:** abrir → escrever → flush → fechar a cada
   registro, sem manter o arquivo aberto. Assim o cartão fica sempre consistente
   e, no pior caso, perde-se **só o último registro**, nunca o cartão inteiro.

Gravação segura resolve ~95% sozinha; o supercap cobre a janela rara do "morreu
no meio da escrita". No projeto, isto **não é luxo, é requisito** — queda de
energia é o cenário-título.

### 7.7 Telegram como relé grátis — parcialmente adotável **[análise]**

Ideia do autor: usar a **Bot API do Telegram** para escapar da nuvem paga. Boa —
mas serve numa direção só. Entender isso agora evita descobrir na hora de
implementar.

**A parede:** a Bot API é **bot↔usuário**, não um cano genérico entre dois
programas seus (app e hub).

- **Aviso (hub → celular): funciona lindamente, grátis.** O hub chama
  `sendMessage` e a mensagem chega. **Fácil de fazer do ESP32** (é só uma
  requisição HTTPS com o token na URL — ao contrário do FCM, que exige assinar
  token OAuth2/JWT). **Candidata a aposentar o FCM** para o alerta crítico;
- **Comando (app → hub, invisível): trava.** O `getUpdates` do hub só entrega
  mensagens que **usuários** mandaram *para* o bot. O app não é usuário; se usar o
  token do bot, a mensagem sai como *bot → chat* e **o `getUpdates` não a vê**.
  Não há jeito limpo de o app injetar um comando pela Bot API.

**As saídas do comando, e por que nenhuma é grátis de verdade:**

1. App virar usuário Telegram (MTProto/TDLib) → precisa de **conta com número**;
   a do produtor (fricção/privacidade) ou uma por aparelho (o Telegram **bane
   criação em massa**). Serve para protótipo, não para produto;
2. Produtor mandar o comando pelo Telegram (modelo **visível**) → funciona, mas
   deixa de ser invisível, que era a graça;
3. Voltar a ter um pedacinho de servidor (função serverless) como cérebro do bot.

**O ponto que fecha:** se o comando exige cola no servidor de qualquer jeito
(opção 3), o **relé MQTT mínimo** (seção 5–6) é melhor — é feito para mensagem
bidirecional app↔hub atrás de NAT, ~US$ 5/mês para milhares. Torcer uma API de
chatbot para virar fila de mensagem dá mais trabalho e menos garantia.

**Veredito:** adotar o Telegram como **canal de alerta grátis** (hub → celular,
uma direção, pode substituir o FCM) **e** o **relé MQTT** para o comando/remoto
bidirecional. Um não substitui o outro — cada um na perna que faz bem.

### 7.8 Alternativas avaliadas e descartadas **[análise]**

Guardadas com o **motivo**, para não voltarem daqui a meses e refazerem o mesmo
raciocínio.

**Usar o roteador do produtor como servidor/hub (OpenWrt).** Tecnicamente
possível — um roteador com OpenWrt roda Mosquitto, servidorzinho, SQLite, e já
está sempre ligado e conectado. **Descartado como produto** por três motivos:

1. **Não se controla o roteador do cliente.** No interior ele é quase sempre
   **do provedor**, trancado. Não dá para vender um produto cujo passo 1 é
   "regrave seu roteador" — risco de brickar, perda de garantia, produtor não
   técnico;
2. **Fragmentação:** cada casa tem um modelo; os do provedor são os que menos
   aceitam OpenWrt;
3. **Não resolve o rádio:** roteador só fala Wi-Fi — **não fala ESP-NOW nem
   LoRa**. Continuaria precisando de um ESP/módulo para alcançar as estufas. E se
   já é preciso um ESP com rádio, é ele que deve ser o hub — o roteador não
   acrescenta nada.

**Convergência:** "roteador virar servidor" e "hub ESP na rede" terminam no mesmo
lugar — um aparelho **que o autor fabrica e controla** na propriedade. Serve para
o **protótipo pessoal** (com um roteador próprio flashável), não para o produto.

### 7.9 Conceito: "servidor" e por que o remoto sempre precisa de máquina alugada **[análise]**

Base que explica por que o relé é inescapável — e evita achar que "um servidor
mais forte" resolveria o remoto.

**"Servidor" é um papel, não um tipo de máquina.** É qualquer máquina rodando um
programa que espera alguém conectar e responde. Datacenter, PC, Raspberry Pi ou
ESP32 fazem esse papel. O ESP **já é** um servidor (serve `/status`). Então "ESP
como hub" e "PC como servidor" são o mesmo papel, em portes diferentes.

**Dois eixos independentes, e confundi-los é o erro comum:**

| Eixo | ESP em casa | PC em casa | VPS (datacenter) |
|---|---|---|---|
| **Capacidade** (RAM, banco, conexões) | suficiente p/ sensores | exagerada | boa |
| **Alcance remoto** | atrás do NAT | **atrás do NAT (igual)** | **IP público** |
| Energia/custo | centavos | alto, 24h | ~US$ 5/mês |

**Potência não compra alcance.** Um PC em casa tem a MESMA parede de NAT que o
ESP — trocar um pelo outro não resolve o remoto. Render/VPS funcionam de fora não
por serem fortes, e sim por estarem num **datacenter com IP público**.

**Como o hub "ganha" endereço público:** ele não ganha. O endereço público mora
numa **máquina alugada** (VPS), e o hub **conecta para fora** até ela — o público
fica na máquina alugada, dividida por todos os hubs. Essa máquina é o "Render
próprio", minúsculo e sem estado (o relé das seções 5–6).

**Caminhos concretos:**

- **Protótipo (grátis, rápido):** túnel — Cloudflare Tunnel, Tailscale, ngrok. O
  hub abre túnel de saída, o serviço dá uma URL pública. Atravessa CGNAT, sem
  mexer no roteador. **Não é para produto** (hóspede de API grátis, custo por
  aparelho);
- **Produto:** alugar um **VPS** (~US$ 5/mês ou camada gratuita) com IP público,
  rodando o relé; todos os hubs conectam para fora. Um serve milhares;
- **Evitar:** *port forwarding + DDNS* — exige acesso ao roteador e IP público do
  provedor (CGNAT mata), expõe o hub, e não dá para pedir a cada produtor.

**Conclusão:** endereço público só vem de máquina que tem um; casa não tem (PC ou
ESP, igual). Logo o remoto **sempre** precisa de uma máquina alugada em algum
ponto. A meta nunca foi "não pagar", e sim pagar o **mínimo**: uma máquina barata,
sem estado, dividida por todos — e, para o alerta crítico, nem ela (Telegram, 7.7).

### 7.10 Relés grátis: o gargalo é conexão, não armazenamento **[análise]**

O relé só passa mensagem (leitura, comando); o histórico fica no **SD do hub**.
Logo o relé quase **não precisa de armazenamento** — guarda no máximo a última
leitura e um comando pendente por aparelho (bytes). O que limita é **conexões
simultâneas** e **mensagens/mês**, não memória.

**Conta das conexões:** cada hub mantém **1** conexão permanente com o broker; o
celular só conecta **quando o app está aberto**. Simultâneos ≈ nº de hubs +
celulares ativos no momento.

**Opção A — gerenciado (pronto, teto de conexões, termos de terceiro):**

| Serviço | Grátis típico (confirmar — muda) |
|---|---|
| HiveMQ Cloud (MQTT) | ~100 conexões |
| EMQX Cloud serverless | generoso em "minutos de sessão" |
| **Firebase Realtime Database** | ~100 conexões, 1 GB, 10 GB/mês |
| Ably / PubNub | ~200 conexões, milhões de msg/mês |

O **Firebase RTDB** é atraente porque o projeto **já usa Firebase** (FCM): o app
escreve o comando num caminho, o hub tem um ouvinte que dispara na hora, atravessa
NAT (saída). Teto de ~100 conexões é a pegadinha na escala.

**Opção B — hospedar (sustentável para milhares):** rodar **Mosquitto** (broker
grátis) numa VM **Oracle Cloud Always Free** (grátis para sempre) ou VPS de
~US$ 5. Uma VM de 1 GB segura **milhares** de conexões MQTT leves, sem custo por
mensagem, sem limite de storage artificial, e **sob teu controle**.

**Quantos simultâneos:**

- Gerenciado grátis: ~100–200 conexões → **~100 propriedades**. Bom para começar,
  não para milhares;
- Mosquitto próprio numa VM barata/grátis: **milhares**. O gargalo é conexão,
  nunca storage.

**Caminho para o hub ESP + SD:**

1. Agora/protótipo: **Firebase RTDB** (já tem) ou **HiveMQ grátis** — sem alugar
   nada;
2. Ao escalar: **Mosquitto** no **Oracle Always Free** / VPS US$ 5 — "Render
   próprio", milhares de hubs, custo fixo minúsculo;
3. Alerta crítico: **Telegram**, grátis, sem tocar no relé (7.7).

**Ressalva:** limites de plano grátis **mudam** — confirmar antes de apostar.
Gerenciado = conveniência com teto e termos de terceiro; Mosquitto próprio = mais
setup, mas controle e escala reais. Para produto, o próprio ganha.

### 7.11 Quando sair do grátis: tabela de gatilhos **[análise]**

Para planejar a migração **antes** de quebrar. Princípio: **agir aos ~80% do
limite**, não em 100% — migra-se sem apagão para o produtor. Números típicos;
**confirmar no painel de cada serviço** (eles mudam).

**Boa notícia:** na arquitetura de hub, o 1º passo **pago** fica longe. O caminho
é *grátis gerenciado → grátis auto-hospedado (Oracle Always Free) → pago*; o meio
é coberto de graça, então "sair do grátis de verdade" só nos milhares.

**Arquitetura-alvo (hub + SD + relé):**

| Recurso | Limite grátis | ≈ propriedades | Vigiar / onde | Gatilho (80%) | Ação |
|---|---|---|---|---|---|
| FCM (push) | sem limite prático | qualquer | nada | — | nenhuma |
| Histórico (SD do hub) | nenhum na nuvem | qualquer | espaço do cartão, no hub | cartão ~80% | cartão maior / retenção |
| Relé gerenciado (RTDB, HiveMQ) | ~100 conexões | ~100 | conexões simultâneas, painel | ~80 conexões | Mosquitto no Oracle Always Free (ainda $0) |
| Relé auto-hospedado (Mosquitto/Oracle) | ~milhares (RAM da VM) | milhares | RAM/CPU da VM | RAM ~80% / CPU alto contínuo | VPS maior (US$ 5 → 10–20) |

**Arquitetura atual (Render + Supabase) — gatilhos vêm antes, por storage:**

| Recurso | Limite | Vigiar / onde | Gatilho | Ação |
|---|---|---|---|---|
| Supabase (banco) | 500 MB | aba Usage | ~400 MB | dedup/retenção (feito) ou mover histórico p/ o SD |
| Render (free) | ~750 h/mês + dorme | Metrics | 1 serviço já ocupa quase tudo | VPS |

**Como monitorar:** o melhor alarme antecipado é o **painel de uso do próprio
provedor** — Firebase console (Usage), Supabase (Usage, que já salvou uma vez),
Render (Metrics). Olhar 1×/mês no começo; a cada 2 semanas quando o crescimento
acelerar.

### 7.12 Sazonalidade: pagar só na safra **[campo + análise]**

**[campo]** O uso é sazonal: a secagem na estufa concentra-se na **colheita, de
dezembro a fevereiro/março no RS** (~3-4 meses); plantio é julho-agosto. Fora da
janela de secagem, quase não há o que monitorar. (Confirmado por pesquisa:
Agrolink, calendário agrícola do RS.)

**[análise]** Isso é **vantagem de custo** — a infraestrutura paga só precisa
existir na safra. A regra é escolher cobrança que encolhe na entressafra:

- **Por uso (naturalmente sazonal):** Firebase Blaze, VPS por hora (DigitalOcean,
  Vultr, AWS) — sem aparelho conectado, a conta cai para ~zero sozinha. FCM e
  Telegram, grátis sempre;
- **Mensal fixo (exige ação):** Render Pro, Supabase Pro, VPS mensal — pagam
  usando ou não; na entressafra, **pausar ou rebaixar**;
- **O relé (VPS) pode ser destruído e recriado por safra** — ele é **sem estado**
  (histórico no SD do hub), então paga-se ~4 meses, não 12 (~2/3 de economia).

**Truque para recriar sem dor:** manter **estável o endereço** (domínio ou IP
reservado) e trocar só a máquina atrás dele; um **script/snapshot** sobe o relé
em um comando. Assim os hubs continuam achando o mesmo nome.

**Bônus edge-first:** na entressafra o produtor não cura, então nem precisa do
remoto; e o controle local funciona o ano todo. O vale de uso é real e profundo.

**Ressalvas:** automatizar o "ligar" antes da safra (o risco é esquecer e começar
no escuro); regiões **escalonam** a safra, então a "temporada ligada" com muitos
produtores é um pouco maior que os 4 meses de um só; o **domínio** é custo anual
fixo (~US$ 10-15), independente de estação.

### 7.13 Ainda em aberto

- **Outras ideias do autor** (a conversa continua);
- Custo real do VPS/broker na escala pretendida (números, não só ordem de
  grandeza);
- Desenho do relé MQTT: autenticação por propriedade, TLS, como o hub e o celular
  se encontram;
- Detalhe do disparo do FCM (função serverless grátis vs. outra via);
- Reescrita da camada de comunicação da estufa para ESP-NOW/LoRa (deixa de ser
  HTTP/JSON e vira pacote binário — trabalho relevante no firmware);
- Escrita segura no SD contra queda de energia;
- Migração: sair de Render/Supabase sem quebrar quem já usa;
- Regulatório: faixa 915 MHz (ANATEL) se o LoRa virar produto.

## 8. Relação com o TCC

Não é necessário para o trabalho — a arquitetura atual prova o conceito. Mas
rende uma seção forte de **viabilidade comercial / trabalhos futuros**: mostra
que o projeto foi pensado além do protótipo, com consciência de custo e de
escala. Ver também `AMBIENTE_ESTUFA.md` (limitações de hardware) como material da
mesma natureza.
