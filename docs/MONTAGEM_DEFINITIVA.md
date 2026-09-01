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

### Falta — nacional

| Item | Especificação | ~R$ |
|---|---|---|
| **Caixa IP67** | ~200 × 120 × 75 externo — **confirmar o INTERNO antes** | — |
| **Fonte 5 V / 2 A** | com selo INMETRO, plugue brasileiro | — |
| **Verniz de proteção** acrílico | Implastec ou equivalente **com ficha técnica** | 30–40 |
| **Álcool isopropílico** | limpar o fluxo antes de envernizar | 15 |
| **Multímetro** | qualquer um com bipe de continuidade | 25–40 |

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
1 × 4,7 kΩ), **estanho 63/37 com fluxo** e **ferro de solda de 30 W** — este
precisa da ponta limada e restanhada, não trocada.

Fio rígido para os pulos na placa sai das **pernas cortadas dos resistores** e de
um pedaço de cabo de rede velho.

### Para a etapa do cabo longo (não é agora)

- Resistor **2,2 kΩ** — substitui o 4,7 kΩ do DHT22 quando o cabo for a 5 m
- Resistor **4,7 kΩ** extra — pull-up do sensor de chama no cabo longo
- **AM2302 com 5 m** de fábrica, ou o curto com emenda **fora da estufa**

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

**Pulos com capa, barramentos nus.** Todo sinal atravessa pelo menos um barramento
no caminho; fio nu ali seria curto. Os barramentos correm sozinhos na sua linha e
por isso podem ser nus.

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
