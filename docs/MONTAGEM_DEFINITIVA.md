# Montagem definitiva — do protoboard para a estufa

O aparelho que rodou os testes de campo está em **protoboard**, e protoboard é
montagem de bancada. Este documento é o que comprar e por quê para transformá-lo
em algo que aguenta uma safra.

> **Por que sair do protoboard.** Ele segura o fio por *pressão de mola*.
> Vibração, dilatação térmica e umidade soltam contato com o tempo, e o modo de
> falha é o pior possível: **intermitente**. Não quebra de vez — falha às 3 h da
> manhã e volta quando alguém vai olhar. Numa estufa quente e úmida os contatos
> oxidam rápido.

## Pinagem atual (fonte: `firmware/sentinela_esp32/sentinela_esp32.ino`)

| Sinal | GPIO | Sai da caixa? |
|---|---|---|
| DHT22 (dado) | 32 | sim |
| Sensor de chama | 35 | sim |
| Botão do buzzer | 13 | painel |
| Botão verde | 4 | painel |
| Botão vermelho | 33 | painel |
| LED de alerta | 26 | painel |
| LED de umidade | 27 | painel |
| LED de controle de temperatura | 14 | painel |
| Buzina | 25 | sim |
| Display TM1637 — CLK | 18 | painel |
| Display TM1637 — DIO | 19 | painel |
## Lista de compra

O que decide a loja é o **prazo**, não o preço: AliExpress leva de 15 a 40 dias
mais imposto, e não serve para nada que precise estar pronto antes da banca.

### Já comprado

**Nacional (21/08/2026)** — é o que permite soldar:

| Item | Especificação |
|---|---|
| **Placa ilhada** | 9 × 15 cm, 2,54 mm, fibra de vidro dupla face |
| **Barra de pinos fêmea** | 1×40, 2,54 mm, comum/estampada |
| **Borne KRE 2 vias** | passo 5,08 mm, 12 un |

**AliExpress (21/08/2026, R$103,74)** — chega em 15 a 40 dias, é a etapa
definitiva:

| Item | Variante |
|---|---|
| Sensor de chama **LM393** | 4 pinos, 5 un |
| **DS18B20** à prova d'água | sonda 5 m + módulo com pull-up embutido |
| **Prensa-cabo PG7** | 10 un — cabo 3–6,5 mm, **furo 13–13,5 mm** |
| **Válvula de respiro** M5×0,8 | 10 un, membrana PTFE, **com contraporca** |
| Capacitor cerâmico **104 (100 nF)** | 100 un, 50 V |
| Termorretrátil **4:1 com cola** | 12 mm, 1 m |

**Nacional (01–06/09/2026)** — comprados durante a montagem:

| Item | Especificação |
|---|---|
| **Multímetro** | B Basto MD-180L, bipe de continuidade, bateria inclusa |
| **Ferro de solda 60 W** | com regulagem e pontas extras — o de 30 W queimou no meio da fiação |

### Falta — para fechar a montagem

| Item | Especificação | ~R$ |
|---|---|---|
| **Chave de fenda pequena** | 2 a 2,5 mm, ou jogo de precisão — **trava os 22 parafusos hoje** | 5–25 |
| **Caixa IP65 ou IP67** | **interno a partir de 300 × 150 × 100** — ver a seção do acionamento | — |
| **Espaçadores sextavados de nylon** | **M3 × 10 mm**, com parafusos de nylon, 4 un — suspendem a placa; a face do cobre tem biquinhos de solda e **não pode encostar em nada**. Nylon por ser isolante; nada de autoadesivo, que solta em caixa quente | 10–20 |
| **Verniz de proteção** | Implastec ISOTEC ou equivalente **com ficha técnica** | 45–70 |
| **Álcool isopropílico** | 99,8% — o de farmácia é 70% e leva água junto | 19 |

### Alimentação: não comprar fonte de parede

Chegou a entrar na lista uma fonte 5 V/2 A com plugue P4. **Saiu**, por dois
motivos que se somaram.

Na bancada, o **USB do computador** alimenta e ainda serve de proteção: a porta
limita corrente e desiste diante de um curto, coisa que uma fonte de 2 A não faz.

Para rodar na estufa antes da etapa do acionamento, **um carregador de celular que
já existe em casa** resolve: corta-se um cabo USB, e os fios de 5 V e terra vão nos
bornes `A` e `C` da borda de cima. Carregador de celular é certificado, o consumo
do aparelho é de uns 400 mA, e o custo é zero.

E na etapa do acionamento a fonte de parede **desaparece de qualquer forma**: com
uma caixa só e um cabo só, o conversor de 5 V passa a ser um módulo interno. Uma
fonte comprada agora seria jogada fora lá.

### Falta — loja de material elétrico da cidade

| Item | Observação |
|---|---|
| **Abraçadeiras de nylon** | alívio de tração |
| ~~Cabo do sensor~~ | **resolvido**: ja ha cabo de rede **FTP (blindado)** em casa |
| **Broca escalonada** | precisa chegar a **13,5 mm** para o PG7 |

**O cabo esta resolvido: e FTP.** O cabo de rede que ja havia em casa tem folha
de aluminio e fio dreno — blindado, e melhor que o cabo de alarme que estava na
lista. Confirmado em 26/08/2026.

**A blindagem so funciona aterrada em UMA ponta — a da placa.** Na ponta do
sensor, folha e dreno sao cortados rentes, isolados e deixados soltos. Aterrar
nas duas pontas cria laco de terra: a malha vira caminho de corrente entre dois
terras de potenciais diferentes e passa a **injetar** ruido em vez de barrar,
ficando pior que cabo nenhum. O sintoma seria justamente o que se queria evitar —
leitura instavel sem causa aparente.

Use **um par trancado** para dado + terra (e o trancado que rejeita ruido) e
**outro par, com os fios unidos**, para o 3,3 V. Sobram dois pares para o sensor
de chama. Ao descascar, nao cortar a folha junto: rompida no meio do trecho, a
blindagem so vale ate ali.

### Já tem, não precisa comprar

ESP32, display TM1637, botões, LEDs, buzina, os 4 resistores em uso (3 × 220 Ω e
1 × 4,7 kΩ), **estanho 63/37 com fluxo** e **cabo de rede FTP**, que deu tanto os
barramentos nus quanto os 20 fios dos componentes.

**Carregador de celular** — é ele que alimenta o aparelho até a etapa do
acionamento. Ver a seção da alimentação acima.

### Pendência: o DS18B20 comprado não tem lugar no firmware

Ele foi comprado em 21/08 com sonda de 5 m, e **o firmware não lê nenhum
DS18B20** — a temperatura sai toda do DHT22, no `GPIO 32`. A placa montada também
não tem borne para ele.

Fica registrado como pergunta em aberto: ou ele assume a temperatura e o DHT22 fica
só com a umidade — o que exige borne, GPIO e código novos —, ou ele sobra. Decidir
antes de furar a caixa, porque muda quantos prensa-cabos ela precisa.

### Para a etapa do cabo longo

O DS18B20 **já chega com 5 m**, e o DHT22 vai para a mesma distância. Então esta
etapa deixou de ser hipotética.

**Os capacitores 104 já comprados são para isso.** Cinco metros de cabo fazem a
alimentação balançar na ponta do sensor a cada transmissão do Wi-Fi ou toque de
buzina, e a leitura falha sem causa aparente. Um 100 nF **entre `VCC` e `GND`,
encostado no corpo do sensor**, segura a tensão local.

| Onde | O quê |
|---|---|
| **DHT22** | um 104 entre `+` e `−`, colado no sensor — é o mais sensível dos três |
| **Sensor de chama** | um 104 entre `VCC` e `GND` da plaquinha |
| **DS18B20** | conferir antes: a plaquinha adaptadora traz dois SMD, e um deles pode já ser o capacitor |
| **Placa** *(opcional)* | um 104 entre os dois barramentos da borda de baixo — eles ficam a 2 furos, que é o espaçamento das pernas |

Sobre os pull-ups a 5 m, um por vez:

- **DS18B20** — os 4,7 kΩ da plaquinha dão conta. Esse sensor trabalha a dezenas de
  metros. **Nada a mudar.**
- **DHT22** — a troca por **2,2 kΩ** continua prevista, mas **não se faz antes de
  precisar**: 5 m com 4,7 kΩ costuma funcionar, e o 4,7 kΩ está soldado na placa.
  Ligar o cabo longo primeiro; dessoldar só se a leitura falhar.
- **Sensor de chama** — precisa do **4,7 kΩ extra**, e por outro motivo: o `GPIO 35`
  não tem pull-up interno, e cabo rompido deixa o pino flutuando. Sem ele, um cabo
  partido faz o aparelho gritar incêndio sem incêndio.

Sobre o sensor de umidade: **AM2302 com 5 m** de fábrica, ou o curto com emenda
**fora da estufa**.

### Para a etapa do acionamento (pós-banca)

O porquê de cada um está na seção *Acionamento da ventoinha*. Aqui é só o que se
compra.

| Item | Especificação |
|---|---|
| **Módulo relé 1 canal 5 V** | optoacoplador e **ranhuras de isolamento**, pacote de 5 |
| **Contator** | tripolar pequeno (9 A serve de sobra), **bobina 220 V** |
| **Fonte AC/DC interna** | **5 W** (HLK-5M05 ou equivalente), não a de 3 W — ver a conta do consumo |
| **Fusível + porta-fusível** | **2 A retardado** — rápido queima no arranque |
| **Tomada de embutir** | 10 A **com pino terra**; a plaqueta manda aterrar o motor |
| **Capacitor supressor** *(opcional)* | 100 nF **classe X2, 275 VAC** — cerâmico de 50 V não serve. Vai na **bobina do contator** |
| **Resistor do supressor** *(opcional)* | 100 Ω / 1 W — o par RC é para bobina **de 220 V CA**; diodo só serviria em bobina de corrente contínua |
| **Resistor de segurança** | segura a linha do relé desligada durante o boot |
| **Fio 1,5 mm²** | fase, neutro e terra |
| **Conectores Wago** | emendas da rede — nunca fita |
| **Divisória** | chapa de plástico ou acrílico, separando rede de baixa tensão |

Só um relé por aparelho: o aparelho chaveia a ventoinha e nada mais. O pacote de
cinco vira **um em uso e quatro de reposição**, que é o que uma peça de desgaste
pede.

## Jumpers: nenhum

Jumper é **o mesmo contato por pressão do protoboard**, num invólucro melhor.
Levá-lo para a montagem final leva o problema junto.

Use **borne de parafuso e fio**: aperta, não solta com vibração, e permite trocar
um sensor com chave de fenda no meio da estufada.

A única exceção é a **barra fêmea do ESP32**, e ela se justifica: o módulo
precisa poder sair se queimar, é encaixe firme e ninguém mexe nele depois de
montado. Soldar o ESP32 direto significa perder a placa junto com ele.

## O multímetro não é para depurar, é para não queimar

Ele entra na lista por um motivo só: **conferir curto entre as vias de um borne
antes de ligar a fonte**. O borne da força carrega `VIN` e `GND` lado a lado, a
duas colunas de distância, e um fio de estanho entre os dois transforma o
primeiro `ligar` em fonte esquentando.

**Sem ele, a regra é: nunca energize pela fonte de parede primeiro.** A primeira
energização é **pelo USB do computador** — a porta USB tem proteção de corrente e
desliga sozinha em vez de insistir. Se o ESP32 não aparecer no `arduino-cli
board list`, desligue e procure o curto antes de tentar de novo.

Isso não substitui a medição; só troca "queimar" por "não ligar".

## A conta dos bornes fecha em 12 — com terra comum

Cada fio que sai da placa precisa de uma via de borne. Somando um por sinal:
alimentação (1), display (2), DHT22 (2), sensor de chama (2), buzina (1), três
LEDs (3), três botões (3) — dá **14 bornes**, e há 12.

**O terra comum resolve, e não é economia forçada.** Os três LEDs voltam todos
ao GND, e os três botões também; um único retorno serve aos três:

| Grupo | Bornes | Vias |
|---|---|---|
| LEDs | 2 | alerta, umidade, controle, **GND comum** |
| Botões | 2 | buzzer, verde, vermelho, **GND comum** |

De 14 para **12** — exatamente o comprado. Barramento de terra comum no painel é
prática corrente: o retorno não carrega informação, só corrente, e as correntes
aqui são de miliampères.

**Confira isso antes de soldar o primeiro borne.** Descoberto no meio da
montagem, o erro obriga a dessoldar bornes já fixados — e dessoldar borne de
placa ilhada é o que arranca ilha.

## Conferir a placa antes de fechar a caixa

`firmware/teste_placa/teste_placa.ino` acende um LED por vez, toca a buzina,
conta no display e imprime botões e sensores no Serial.

Ele existe porque o firmware não serve para isso: os LEDs só acendem quando a
temperatura sai da faixa e a buzina só toca em alarme, o que é demorado de
reproduzir na bancada. Cada sintoma tem um significado direto:

| O que se vê | O que é |
|---|---|
| Dois LEDs acendem juntos | ponte de solda entre eles |
| Número parado no display | CLK ou DIO sem contato |
| Número embaralhado | CLK e DIO trocados |
| Botão nunca sai de `solto` | o fio não chega ao GPIO, ou falta o GND comum |
| DHT22 sempre `SEM LEITURA` | falta o pull-up de 4,7 kΩ, ou o dado não chega ao GPIO 32 |

## O que foi construído — mapa da placa

Montada em 26–29/08 e 01/09/2026. Coordenadas na serigrafia da própria placa:
letra na borda comprida, linha contada a partir da borda.

**Referências fixas:** barras fêmea do ESP32 nas colunas `G` a `U`, linhas 12 (lado
`VIN`) e 22 (lado `3V3`). Bornes nas linhas 4 e 30, colunas `A` `F` `K` `P` `U` `Z`.

**Barramentos** — fio nu deitado sobre as ilhas:

| Barramento | Linha | De → até | Desce até |
|---|---|---|---|
| Terra, borda de cima | 6 | `A` → `B₂` | `GND` da linha 12, coluna `H` |
| Terra, borda de baixo | 28 | `A` → `Z` | `GND` da linha 22, coluna `H` |
| 3V3, borda de baixo | 26 | `A` → `W` | `3V3` da linha 22, coluna `G` |

**Borda de cima (linha 4):**

| Via | Recebe |
|---|---|
| `A` | `VIN` (linha 12, col `G`) |
| `C` | terra |
| `F` | `D25` — buzina (col `N`) |
| `H` | terra |
| `K` | `D14` — LED de controle, via 220 Ω (col `K`) |
| `M` | `D26` — LED de alerta, via 220 Ω (col `M`) |
| `P` | `D27` — LED de umidade, via 220 Ω (col `L`) |
| `R` | terra comum dos LEDs |
| `U` | `D13` — botão do buzzer (col `I`) |
| `W` | `D33` — botão vermelho (col `O`) |
| `Z` | `D4` — botão verde (linha 22, col `K`) |
| `B₂` | terra comum dos botões |

**Borda de baixo (linha 30):**

| Via | Recebe |
|---|---|
| `A` | 3V3 — display |
| `C` | terra — display |
| `F` | `D18` = `CLK` do display (linha 22, col `O`) |
| `H` | `D19` = `DIO` do display (linha 22, col `P`) |
| `K` | terra — DHT22 |
| `M` | *livre* |
| `P` | `D32` — dado do DHT22 (linha 12, col `P`) |
| `R` | 3V3 — DHT22 |
| `U` | `D35` — `DO` do sensor de chama (linha 12, col `Q`) |
| `W` | 3V3 — sensor de chama |
| `Z` | terra — sensor de chama |
| `B₂` | *livre* |

**As duas vias livres são o troco dos sensores de três fios**, não esquecimento: o
DHT22 ocupa duas vias de um borne e uma do vizinho, e o de chama faz igual. Se um
dia entrar relé, é onde ele se parafusa.

**O 4,7 kΩ do DHT22** liga as vias `P` e `R` da borda de baixo direto, sem fio: elas
já são o dado e o 3V3. Sem ele o sensor devolve leitura vazia para sempre, e o
sintoma não denuncia a causa.

**Medido na placa montada em 01/09/2026: 4,64 kΩ** — dentro da tolerância. Os três
dos LEDs foram medidos no mesmo dia e dão 220 Ω. Os quatro valores tinham sido
escolhidos por eliminação, sem ler as faixas; a medição confirmou os quatro.

A leitura só sai certa na escala de **20 kΩ**. Na posição do bipe este multímetro
mostra **milivolts do teste de diodo**, não ohms — ali o mesmo resistor aparece
como `862`, que é 0,862 V; e na escala de 2 kΩ ele dá `0L` por estourar o fim de
escala. Vale para qualquer medição futura: **`0L` numa escala de resistência quer
dizer *maior que esta escala*, não *aberto***. Só depois de estourar a maior é que
a ligação está aberta de verdade.

**Pulos com capa, barramentos nus.** Todo sinal atravessa pelo menos um barramento
no caminho; fio nu ali seria curto. Os barramentos correm sozinhos na sua linha e
por isso podem ser nus.

## Acionamento da ventoinha — decidido, não construído

**Não entra antes da banca.** Os cinco objetivos declarados são monitorar,
controlar, sincronizar, registrar e alertar — e o "controlar" é o produtor mudar o
ajuste, inclusive de longe. Chavear carga muda o que o aparelho declara ser.

Mas as decisões foram tomadas em 06/09/2026 e ficam registradas, porque **algumas
delas mudam compras que se fazem agora**.

### O motor (medido na plaqueta)

WEG, 22ABR19, item 14126484. **0,09 kW — 1/8 cv**, 3470-3510 rpm, regime S1,
IP44, FS 1,15.

| Tensão | Corrente | Partida (Ip/In 4,6) |
|---|---|---|
| 127 V | 1,72 A | ~7,9 A |
| **220 V** | **0,86 A** | **~4,0 A** |

**A estufa é 220 V**, então a partida é de 4 A. Mas o "10 A" do relé não é a
comparação certa: aquele número vale para carga resistiva, e motor não é isso.

A comparação que vale é a **classificação em cavalos** que esses relés trazem para
carga de motor, tipicamente **1/3 cv em 250 V**. O motor é de **1/8 cv** — menos da
metade. Não cabe apertado: está dentro da faixa de motor do próprio contato.

**Relé e contator são a mesma ideia em tamanhos diferentes** — bobina puxando um
contato. O contator entra de meio cavalo para cima, quando a partida vai a 15 ou
20 A; e mesmo lá o relé não sai de cena, ele passa a acionar o contator. Loja e
buscador que recomendam contator para "um motor" estão certos sem a plaqueta: sem
o número, cautela é a resposta correta. **Foi a plaqueta que mudou a resposta.**

Ou seja: **o relé chavearia este motor direto**, sem contator. A plaqueta manda
aterrar o motor, então o terra atravessa a caixa até o pino da tomada de saída.

### E mesmo assim entra contator — por desgaste, não por corrente

Decidido em 06/09/2026, depois de o produtor informar que **a ventoinha liga
várias vezes por estufada, sem padrão**.

Poder chavear não é durar. Cada abertura sob carga de motor abre um arco que come
um pouco do contato, e relé morre por **número de operações**, não por corrente.
Estimando 20 vezes por hora numa estufada de seis dias, são ~2.900 operações; vinte
estufadas passam de 50 mil, e relé desse tipo vive na casa das 100 mil. **Uma ou
duas safras.**

Com contator no meio, **o relé nunca chaveia o motor** — ele fecha o caminho até a
bobina, que é carga leve e previsível. O arco do motor passa a ser aberto por
contatos com câmara de extinção, feitos para isso, e que se contam em centenas de
milhares de operações. Gastando um dia, contator é peça de prateleira e os contatos
se trocam; relé soldado vai fora inteiro.

O desgaste não desaparece — ele **muda de peça**, saindo de uma descartável para
uma projetada e trocável.

De brinde, é a topologia que os aparelhos comerciais usam, e defender isso numa
banca é mais fácil que defender por que se economizou R$ 50 numa peça de desgaste.

**A bobina do contator é de 220 V**, alimentada do mesmo ponto da rede. Assim o relé
só fecha o caminho até ela e nenhuma fonte extra é necessária.

**Se a ventoinha for trocada um dia, a plaqueta nova se lê antes.** O contator dá
folga larga para um motor maior, mas folga tem limite e quem define é o número.

### As três respostas de falha, e o que elas exigem do hardware

Respondidas pelo produtor, que é quem conhece o uso:

| Situação | Decisão |
|---|---|
| Wi-Fi cai | não muda nada — o aparelho decide offline, como os do mercado |
| ESP32 reinicia | ventoinha **não** fica ligada; ele volta e reavalia |
| Aparelho trava | ventoinha **desligada**, por garantia |

As duas últimas têm uma consequência que não é óbvia: **o relé precisa ficar aberto
enquanto ninguém comanda a linha**. Nos primeiros instantes do boot os GPIOs ficam
em alta impedância, e módulo de relé comum pode fechar nesse intervalo. Watchdog
reiniciando passa pelo mesmo boot.

**Exige um resistor segurando a linha de controle no estado desligado.** Barato, e
tem que estar no projeto desde o começo — não é remendo posterior.

### Uma caixa só

Decisão do produtor, e a razão é de mercado: todo aparelho do ramo é assim, e duas
caixas complicam a venda. Aceito — o que muda é o **como**.

- **Divisória de plástico** colada entre o setor da rede e o da placa
- O **contator** é a peça mais alta do conjunto e define a profundidade
- **6 a 8 mm** de isolamento entre trilha de rede e de baixa tensão. O módulo de
  relé precisa ter **ranhuras fresadas** entre o optoacoplador e os contatos
- **Fusível retardado de 2 A** na entrada (rápido queima no arranque, toda vez)
- **Prensa-cabo com alívio de tração** no cabo da rede
- Fio de **1,5 mm²** e emendas em Wago
- Para ficar com **um cabo só** saindo, o conversor de 5 V também vai para dentro,
  e aí a fonte de parede sai de cena

### Os dois caminhos da energia, e o dimensionamento da fonte interna

O cabo de 220 V entra uma vez e **se divide em dois caminhos que não se reencontram**:
um vai ao conversor AC/DC e vira os 5 V da placa; o outro vai ao contato do relé,
segue para a tomada e alimenta a ventoinha **ainda em 220 V**.

**A ventoinha nunca vê 5 V.** O relé não converte nada — ele abre e fecha o caminho,
como um interruptor. E tem duas metades isoladas por dentro: a bobina, que obedece
aos 5 V, e o contato, que aguenta os 220. Entre elas passa movimento mecânico, não
corrente. É isso que deixa o ESP32 mandar sem encostar na rede.

Confusão fácil aqui seria dimensionar a fonte interna pela ventoinha. Ela consome
**0,86 A × 220 V = 189 VA**, e nenhum módulo desses chega perto — nem precisa.

O que a fonte interna alimenta é só o lado de baixa tensão:

| Consumidor | Pico |
|---|---|
| ESP32 nos picos de transmissão Wi-Fi | 500 mA |
| Display | 30 mA |
| Três LEDs | 45 mA |
| Buzina | 30 mA |
| Bobina do relé | 70 mA |
| **Total** | **~675 mA — uns 3,4 W** |

**Por isso a fonte é de 5 W, não de 3 W.** O HLK-PM01 de 3 W entrega 600 mA e fica
abaixo desse pico. Fonte no limite reinicia o ESP32 exatamente quando ele transmite
— e o defeito aparece como problema de rede, que é onde ninguém vai procurar.

**Isso muda o tamanho da caixa a comprar agora:** placa de 150 × 90 mais um setor
de rede de uns 100 × 90 e a divisória. **Interno a partir de 300 × 150 × 100 mm** — é a altura do contator que manda.
Comprar a caixa pequena hoje e a grande depois é pagar duas vezes.

### O relé é peça de desgaste

Ele não morre de corrente — morre de **número de operações**, e a ventoinha liga
sem padrão. Estimando 20 vezes por hora numa estufada de 6 dias, são ~2.900
operações por estufada; vinte estufadas na safra passam de 50 mil. Relé desse tipo
vive na casa das 100 mil com carga leve. **Uma ou duas safras, não cinco.**

**Com o contator no meio, isso deixou de ser problema.** O relé passa a chavear a
bobina — uns 0,1 A, cerca de 1% do que o contato aguenta — e relé trabalhando a um
décimo da nominal vive cinco a dez vezes mais que o catálogo. As 100 mil operações
viram meio milhão ou mais, o que passa de dez safras.

O supressor abaixo **continua ajudando, mas virou opcional**: ele estica algo que já
era suficiente. Não é o caso do pull-up do DHT22, que sem ele o sensor não fala.

Duas formas de esticar:

**Supressor RC em paralelo com o motor** — capacitor 100 nF **classe X2 275 VAC**
em série com resistor de 100 Ω / 1 W. Absorve o arco na abertura. *Não servem os
cerâmicos de 100 nF/50 V comprados para desacoplamento: em 220 V eles rompem, e
cerâmico rompido fecha em curto.*

**Tempo mínimo ligado e desligado, por software** — e essa vale mais que a
primeira. Boa parte do liga-desliga sem padrão é o controle oscilando em volta do
limiar. Um mínimo de minutos ligado e de minutos parado derruba a contagem de
operações sem mudar como a estufa seca. É a mesma ideia da margem de 8 °F, aplicada
ao tempo em vez da temperatura.

O módulo fica **parafusado com os fios em borne, nunca soldado** — troca em dez
minutos com chave de fenda. O pacote de 5 vira 1 em uso e 4 de reposição.

### O LED de controle sai, e a via dele vira a entrada do relé

Decidido em 09/09/2026. O aparelho passa a ter **dois LEDs**, não três.

O firmware aciona três: `LED_ALERTA` (`D26`) quando há fogo ou temperatura fora da
faixa; `LED_UMIDADE` (`D27`) quando o display está **mostrando a umidade** — é
legenda do visor, não aviso de umidade alta; e `LED_CONTROLE_TEMP` (`D14`), que
liga 2 °F abaixo do alvo e desliga 2 °F acima, e vai para o app como
`aquecedorLigado`.

**O terceiro já era o relé em miniatura.** Ele existia para demonstrar o
acionamento enquanto não havia acionamento. Com o relé, a luz perde a função.

**A via `K` da borda de cima fica vazia e recebe o módulo do relé.** Consequências:

- **Nenhuma mudança de placa.** Nada é dessoldado; só não se liga o LED
- **Nenhuma mudança de código** para o comando ligar e desligar — a lógica com
  histerese de ±2 °F já está escrita, testada e rodando. Só o nome da constante
  fica esquisito acionando um contator
- **A histerese de ±2 °F já é o freio do liga-desliga picotado**, antes de qualquer
  tempo mínimo por software
- Restam **dois LEDs, três fios**: alerta na via `M`, umidade na `P`, e um terra
  comum na `R` juntando duas pernas curtas

Dois pontos ficam para aquela etapa: o **resistor de 220 Ω** que sobrou no caminho
(posto para o LED; módulo de relé tem o seu próprio por dentro, e se 220 Ω a mais
incomodar o optoacoplador, troca-se por um fio) e o **resistor que segura a linha
desligada durante o boot**, que é o que cumpre a decisão de "reiniciou, ventoinha
parada".

**Contra-argumento registrado, e recusado pelo produtor:** com o relé fechado dentro
da caixa, o LED seria a única forma de distinguir *"o aparelho não mandou"* de *"o
aparelho mandou e o relé não obedeceu"*. Fica anotado para quem for diagnosticar
ventoinha parada sem ele.

### A lógica é de aquecedor — confirmar antes de ligar o relé

`ledControleLigado` **liga quando esfria** e desliga quando esquenta, e o firmware
chama isso de `aquecedorLigado`. Serve como está se a ventoinha empurra o ar quente
da fornalha. Existindo ela para **resfriar**, o sentido é o inverso e o código
precisa saber. Decidir antes de ligar o relé na via `K`.

**O que comprar para esta etapa está na Lista de compra**, junto com todo o
resto — lista partida em dois lugares não se leva para a loja.


## Conferência da placa montada — 01/09/2026

Feita com multímetro na continuidade, **ESP32 fora dos soquetes**. Com o módulo
encaixado, os caminhos internos dele respondem no lugar da placa.

| O que | Resultado |
|---|---|
| As duas vias de cada um dos 12 bornes | `0L` em todos — **nenhum curto** |
| Terra × 3V3 | `0L` — o curto que mais estraga não existe |
| Os 5 terras contra a referência | apitam |
| Os 3 pontos de 3V3 | apitam |
| Os 12 sinais | apitam (os 3 dos LEDs medem 220 Ω, ver abaixo) |
| As duas descidas de terra até os pinos `GND` | apitam |
| Resistores | 3 × 220 Ω e 1 × 4,64 kΩ |

**Nenhum defeito.** As 22 ligações estão todas lá.

### Três resultados que parecem defeito e não são

**Os três dos LEDs não apitam.** Entre o pino e o borne há 220 Ω, e o bipe só toca
abaixo de umas dezenas de ohms. Mede-se na escala `2k`, esperando 220. Silêncio ali
é o certo; `0L` na escala `2k` é que seria aberto.

**O borne `P` da borda de baixo não apita nem está aberto.** É o pull-up de 4,7 kΩ
ligando as duas vias — na escala `20k` ele mostra 4,64. Isso é o pull-up
funcionando.

**Os dois barramentos de terra não apitam entre si.** Quem junta os dois é o
ESP32, e ele está fora. Apitarem aí é que seria estranho. Cada um se prova contra o
seu próprio pino `GND`.

### E uma armadilha de ponta de prova

Duas medições deram silêncio e, refeitas, apitaram. Era a ponta não pegando no
soquete. **Silêncio numa medição de soquete é mais frequentemente a ponta que a
placa** — é assim que se dessolda uma junta boa. Enfiar uma perna cortada de
resistor no soquete e encostar a ponta nela resolve.

## O ponto fraco da placa são as juntas de superfície

Em 09/09/2026, **dois fios soltaram no mesmo dia**: o que leva o 3V3 ao
barramento e o do display. Não foi azar — os dois eram do mesmo tipo.

*(Houve um terceiro defeito no mesmo dia, mas de outra natureza — está mais
abaixo, e não é junta de solda.)*

**Junta de superfície é fio soldado por cima de uma junta que já existia**, sem
furo segurando. Ela é fraca por dois motivos somados: o fio fica só grudado na
superfície, sem âncora mecânica, e reaquecer estanho velho sem fluxo novo produz
uma liga fosca e quebradiça. Nesta placa elas são a maioria — todo pulo que chega
num pino do ESP32 ou num barramento é uma delas, porque o furo já está tomado.

O que cada uma custou para achar, e o que denunciava:

| Soltou | Sintoma |
|---|---|
| 3V3 → barramento | display apagado, umidade em 0 e temperatura inválida **ao mesmo tempo** |
| ESP32 → display | só o display apagado |

**Sintomas simultâneos apontam para um ponto comum, não para três defeitos.** Foi
o que resolveu o primeiro: display, DHT22 e DS18B20 bebem do mesmo barramento de
3V3, e os três caírem juntos dizia onde procurar.

### Teste de puxão, obrigatório antes de fechar a caixa

Segure cada fio perto da junta e **puxe de leve**. O que se mexer, reaqueça com um
toque de estanho novo — o fluxo novo é o que faz a liga pegar.

Repita **depois** do teste de carregar a caixa até outro cômodo. É o transporte que
encontra a junta que ficou por um fio.

Dez minutos, e é o que separa um aparelho que funciona na bancada de um que
funciona numa safra.

### O terceiro defeito do dia foi outro: fio frouxo em borne de parafuso

O DS18B20 ficou invisível — `DS18B20 encontrados no barramento: 0` — com tudo
apontando para o contrário: o módulo alimentado com 3,28 V e a linha de dado em
3,27 V até o borne. Nada disso era mentira; **o fio solto estava na plaquinha
adaptadora que veio com o sensor**, não numa junta da placa perfurada.

**Fio de sonda é multifilar**, e multifilar em borne de parafuso tem um modo de
falha próprio: os fios finos se abrem ao apertar, o parafuso prende só uma parte
deles, e o contato existe até alguém encostar no cabo.

Por isso o teste de puxão **vale também para os bornes**, e não só para as soldas —
inclusive os das plaquinhas que vieram prontas. Puxe cada fio; saindo, torça as
pontas do multifilar antes de reapertar, para elas entrarem como um feixe só.

## Ligar os componentes — um grupo por vez

Nada foi soldado nos componentes: os 20 fios saem do mesmo cabo de rede FTP.

**A convenção de cor vale para a caixa inteira:** marrom e branco-marrom são
**sempre** terra, laranja é **sempre** alimentação, o resto é sinal. Daqui a dois
anos, com a caixa aberta na estufa, a cor responde sem consultar documento.

Um metro de cabo dá 8 condutores; cada um vira 3 pedaços de 30 cm, e os 20 saem com
sobra — inclusive respeitando a convenção, porque marrom e branco-marrom juntos dão
os 6 terras necessários.

### Três componentes, quatro fios

LEDs e botões não levam um terra cada. As **três pernas curtas dos LEDs se soldam
num nó só**, e dele sai um único fio marrom; os **três botões unem um lado** da
mesma forma.

Não é economia de fio — é o que faz 12 bornes darem conta de 11 coisas. Com terra
individual seriam precisos dois bornes a mais, e eles não existem.

### A ordem, e o que cada grupo prova

Ligar tudo de uma vez deixa cinco defeitos misturados. Um grupo por vez, com o
`teste_placa.ino` rodando, e cada um que responde risca um pedaço da conferência:

| Grupo | Fios | Prova |
|---|---|---|
| Só o USB | — | ESP32 vivo, Serial falando |
| Display | 4 | bornes `A` e `F` de baixo, `D18` e `D19` |
| LEDs | 4 | bornes `K` e `P` de cima, os três 220 Ω, o terra comum |
| Buzina | 2 | borne `F` de cima |
| Botões | 4 | bornes `U` e `Z` de cima |
| DHT22 | 3 | bornes `K`, `P`, `R` de baixo, o 3V3 e o pull-up |
| Sensor de chama | 3 | bornes `U`, `W`, `Z` de baixo |

**Corte com 25 a 30 cm enquanto a caixa não chega.** Não é desperdício: é para isso
que existe borne de parafuso — solta, corta no tamanho, aperta. Nenhuma solda.

**Alimente pelo USB do computador** durante tudo isso. A fonte fica para depois de
a polaridade estar medida.

### Resultado — 09/09/2026

Todos os seis grupos responderam, com o **firmware do aparelho** rodando, não com o
esquete de bancada:

| Grupo | Como foi provado |
|---|---|
| Display | mostra temperatura, e troca para umidade no botão verde |
| Buzina | tocou no alarme de temperatura |
| DHT22 | leitura de temperatura e umidade no lugar de `SEM LEITURA` |
| Sensor de chama | parou de oscilar |
| LED de umidade | acende junto com o display mostrando umidade |
| LED de alerta | acendeu com o alvo afastado do ambiente |
| Três botões | cada um respondeu isolado, nas duas funções que tem |

**O aparelho saiu do protoboard.** A alimentação seguiu pelo USB: o borne da força
continua vazio até haver fonte com a polaridade medida.

### Como provocar cada coisa com o firmware do aparelho

Sem precisar do esquete de bancada, e cada teste isolando um componente:

| Passo | O que aciona | O que prova |
|---|---|---|
| Botão **verde** fora do ajuste | alterna o display entre temperatura e umidade | o botão verde **e** o LED de umidade |
| Botão **vermelho** uma vez | entra no modo de ajuste | o botão vermelho |
| **Vermelho** repetido | +1 °F no alvo; o verde passa a fazer −1 °F | os dois botões na outra função |
| Alvo **~20 °F** longe do ambiente | dispara o alarme | LED de alerta e buzina |
| Segurar o **botão do buzzer** 3 s | cala por 10 min | o terceiro botão |

**Os 20 °F não são engano.** O alarme dispara com 8 °F de desvio, mas logo depois de
mexer no alvo o firmware alarga a margem em até mais 8, dando folga para a estufa
acomodar. Parando nos 8, conclui-se que o alarme está quebrado quando ele está
apenas esperando.

### O que denuncia erro em cada grupo

| Sintoma | Onde está |
|---|---|
| Display com número parado | `CLK` ou `DIO` sem contato |
| Display embaralhado | `CLK` e `DIO` trocados — dois parafusos resolvem |
| Dois LEDs acendendo juntos | dois sinais encostados **no nó**, não na placa |
| LED que não acende | perna longa e curta invertidas |
| Botão sempre `APERTADO` | nos táteis de 4 pernas, foram usadas duas do mesmo par — usar as da diagonal |
| Apertar um botão e dois mudarem | sinais encostados no nó dos botões |
| `chama` oscilando | é o esperado **sem** o sensor: o `GPIO 35` não tem pull-up interno e flutua |

Esse último merece atenção: **se o cabo do sensor de chama romper na estufa, o pino
volta a flutuar e o aparelho pode gritar incêndio sem incêndio.** É por isso que a
lista traz um 4,7 kΩ extra para a etapa do cabo longo — ele segura o pino em alto,
e alto quer dizer *sem fogo*. A falha passa a ser silenciosa em vez de falsa.

## A caixa IP67 não resolve sozinha

IP67 impede água **entrando de fora**. Numa estufa aparecem dois efeitos que a
vedação não cobre:

**Condensação por dentro.** A caixa fecha com ar úmido dentro. A estufada
esquenta, o ciclo acaba, tudo esfria — e aquela umidade vira água na placa. É a
falha clássica de caixa selada com variação térmica, e é traiçoeira porque a
caixa está perfeitamente vedada enquanto acontece. Daí o **respiro de membrana**
(deixa vapor sair, não deixa água entrar) e a **sílica-gel**.

**Calor sem ventilação.** Caixa selada não troca calor. O ESP32 vai até ~85 °C e
a estufa trabalha entre 57 e 79 °C, mais o aquecimento da própria placa — fica na
margem, e os capacitores da alimentação envelhecem rápido nessa faixa.

**A saída é arquitetura, não caixa:** deixar a caixa **fora da zona quente** e
levar só o cabo do sensor para dentro. E lembrar que a caixa só é tão vedada
quanto o furo por onde o cabo passa — furo com borracha improvisada perde o IP67
inteiro. Daí o prensa-cabo.

## Armadilhas de compra

**Display: é TM1637, não TM1650.** Parecem idênticos no anúncio — quatro dígitos,
sete segmentos, dois fios chamados CLK e DIO —, mas o chip é outro e o protocolo
é outro. O TM1650 fala um dialeto tipo I²C com endereço; a biblioteca
`TM1637Display` não conversa com ele. Trocar exigiria reescrever a camada de
display. Comprar **TM1637**, de preferência **0,56 polegada**: o visor mostra o
PIN de configuração e é lido de pé, com pouca luz.

**Tensão do módulo: o ESP32 é 3,3 V.** Muito módulo de sensor é vendido para
5 V, e um sensor de chama com comparador em 5 V joga 5 V na GPIO e queima a
entrada — sem aviso, às vezes só depois de dias. Conferir a tensão de operação de
cada módulo antes de ligar.

**Sensor diferente muda o firmware.** Mesmo modelo é trocar e pronto. Outro tipo
(SHT31, BME280, DS18B20, termopar) muda protocolo e biblioteca.

**Verniz de proteção sem ficha técnica não.** Verniz ruim falha em silêncio: a
placa fica com aparência de protegida e a umidade passa igual — descobre-se meses
depois, com a trilha corroída por baixo. Anúncio que mistura "adesivo, selante e
cola" não sabe o que vende; verniz de proteção **não é cola**. Comprar de
fabricante que declare a base (acrílico, silicone ou poliuretano).

## Um limite do DHT22 que vale conhecer

O DHT22 vai até **80 °C (176 °F)** e o limite de incêndio do sistema é **175 °F**
— ou seja, o sensor chega ao teto dele exatamente onde o alarme importa. Acima
disso ele tende a devolver leitura inválida, e o firmware corretamente descarta
leitura inválida em vez de deixá-la virar zero (um zero falso apagaria um alarme
verdadeiro). Só que descartar também zera `alertaTemperatura`.

Na prática: **superaquecimento extremo pode calar o alarme de temperatura**. Quem
cobre esse caso é o **sensor de chama**, independente e sem esse teto — e é por
isso que ter os dois importa.

### O conserto: DS18B20 para a temperatura, DHT22 para a umidade

| | DHT22 | DS18B20 |
|---|---|---|
| Faixa | até **80 °C** (176 °F) | **−55 a +125 °C** (até 257 °F) |
| Formato | plaquinha exposta | **sonda de inox à prova d'água, com cabo** |
| Umidade | sim | **não** |

O DS18B20 lê durante um superaquecimento de verdade em vez de cegar, e a sonda
com cabo resolve de quebra a arquitetura: eletrônica fora da zona quente, só a
ponta dentro da estufa.

**Ele não substitui o DHT22** — não mede umidade. E, mais importante: no seu
caso **dois sensores separados não são um remendo, são o requisito**.

### Onde cada sensor vai, e por que isso decide a escolha

Na estufa as duas medidas moram em lugares diferentes:

- **Temperatura — embaixo**, onde pega o calor direto.
- **Umidade — no meio do fumo**, colada na parede, depois do corredor entre os
  vãos e a parede da casa de máquina.

Por isso **um sensor combinado (SHT31, BME280) está errado aqui**: ele mede as
duas coisas no mesmo ponto, e uma das duas ficaria no lugar errado por
construção. Foi a primeira recomendação escrita neste documento, e estava errada.

O lugar da umidade também favorece o DHT22: colado na parede, depois do corredor,
é a região mais fria — bem longe dos 80 °C que são o teto dele. O teto só
atrapalhava a medida de temperatura, que agora sai para o DS18B20.

**Pino sugerido para o DS18B20: GPIO23.** Os ocupados são 4, 13, 14, 18, 19, 25,
26, 27, 32, 33 e 35. Evitados: 21 e 22 (I²C padrão, valem como reserva) e os de
*strapping* (0, 2, 12, 15), que atrapalham o boot. O DHT22 fica no 32, agora só
como sensor de umidade.

*Vantagem que casa com estufa:* o 1-Wire aceita **vários DS18B20 no mesmo pino**,
cada um com endereço de fábrica. Temperatura em duas alturas, um dia, não custa
GPIO nenhuma.

### O sensor de umidade já está validado na propriedade

A estufa tem um controlador comercial **Schroeder Tigger 3000** (temperatura,
umidade, alarme, sirene e motor/abafador), e o sensor de umidade dele é um
**AM2302 — o DHT22 com cabo**. Identificado por foto: corpo branco com grade
quadriculada (o DHT11 é azul), aba inferior com furo de fixação e termorretrátil
na junção do cabo.

Ou seja: **o mesmo sensor que este projeto usa mede a umidade daquela estufa há
anos, num produto comercial.** A escolha deixa de precisar de defesa teórica — e
a discussão de SHT31 ou sonda RS485 se encerra: não seriam melhorias, seriam
divergências do que comprovadamente funciona ali.

**Comprar:** `AM2302` ou "DHT22 com cabo", de preferência com **5 m de fábrica**.
Se vier curto, a emenda fica **fora da estufa**, na parte seca — nunca lá dentro.
Vale levar **dois**: é a peça no ambiente agressivo, e ter sobressalente na
gaveta é diferente de esperar entrega internacional no meio de uma estufada.

**Instalação, copiada da que já existe:** tubo atravessando a parede no canto
direito, perto da porta, na altura da verga; cabo por dentro do tubo; sensor
pendurado por um barbante amarrado na aba de fixação, **dentro de um potinho
cortado** para o fumo não encostar direto nele. Aquilo sobreviveu a anos naquele
ambiente — é a prova de campo mais barata que existe.

**Não dividir sinal com o Tigger.** Sinal de instrumento comercial partilhado
perturba os dois lados, e se perderia o controle sobre a única medida que é
nossa. Sensor próprio, no mesmo estilo de instalação.

### O cabo de 5 m do sensor de umidade

O trajeto é por fora da estufa; só o sensor e no máximo 1 m de cabo entram.

O DHT22 usa protocolo de um fio com temporização apertada, **projetado para
20 cm**. A 5 m funciona ou não dependendo do cabo, e o sintoma é leitura inválida
intermitente — não falha limpa. Para dar certo:

- **cabo blindado** ou par trançado de rede: um par para dado + terra, outro par
  (fios juntos) para o 3,3 V;
- **pull-up de 2,2 kΩ** em vez de 4,7 kΩ — cabo mais longo pede pull-up mais
  forte;
- **capacitor de 100 nF** entre VCC e terra **junto ao sensor**, não na placa;
- malha aterrada **só na ponta da placa**, nunca nas duas;
- **sem emenda dentro da estufa** — emenda em ambiente quente e úmido é o ponto
  que oxida primeiro;
- **capinha ventilada** sobre o sensor (furada por baixo, fechada por cima):
  colado na parede ele pega condensação escorrendo.

*Por que aceitar esse risco:* **a umidade não dispara alarme neste sistema.** Uma
leitura perdida custa um ponto no gráfico, e o firmware já descarta leitura
inválida em vez de deixá-la virar zero. Se fosse a temperatura, o risco não valeria.

A resposta tecnicamente correta para 5 m seria uma **sonda SHT20 em RS485/Modbus**
— barramento diferencial, feito para centenas de metros. Fica registrada como o
caminho certo caso isto vire produto: para o TCC é peça, biblioteca e protocolo
novos para melhorar justamente a medida que menos importa.

*Custo da mudança:* entram `OneWire` e `DallasTemperature`, o `lerDHT22()` se
divide em duas leituras e o CI ganha as bibliotecas. Cada sensor precisa do seu
resistor de 4,7 kΩ — serão dois. DS18B20 à prova d'água tem muito clone nesses
marketplaces; leitura travada ou saltando é a primeira suspeita.

*Quando fazer:* **depois da banca.** O aparelho atual tem evidência de campo, e
trocar o sensor principal reinicia essa evidência do zero. É o primeiro item do
trabalho futuro — e um com motivo medido, não com desejo de melhorar.

## Para a apresentação

Protótipo em protoboard **não invalida nada** num TCC, e há evidência mais forte
disponível: dias de funcionamento em estufa real. Se o tempo apertar, apresentar
como está e declarar "montagem definitiva em placa ilhada" como trabalho futuro é
mais honesto — e mais seguro — que uma placa feita às pressas que falha na
demonstração.
