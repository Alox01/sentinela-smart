# Como desenhar esta placa no KiCad, do zero

Este é o caminho para **você** desenhar. O projeto pronto que está nesta pasta
serve de gabarito: travou num ponto, abre o `sentinela.kicad_sch` e compara.

São duas etapas bem separadas. A primeira diz **o que liga em quê** e não tem
tamanho nem posição. A segunda é a placa de verdade. Não dá para pular a
primeira: a segunda nasce dela.

Os nomes de menu abaixo são do KiCad em português. Os atalhos de teclado
aparecem escritos ao lado de cada item do próprio menu — use-os depois, quando
já souber onde cada coisa fica.

---

# Etapa 1 — o desenho elétrico

## 1.1 Criar o projeto

`Arquivo → Novo → Projeto`. Salve numa pasta sua, com um nome sem acento e sem
espaço. O KiCad cria três arquivos de uma vez; clique duas vezes no
**esquemático** para abrir o editor do desenho elétrico.

## 1.2 Ensinar o KiCad onde estão as peças próprias

O ESP32 não vem nas bibliotecas de fábrica — eu desenhei o dele. Para usar:

- `Preferências → Gerenciar bibliotecas de símbolos`, aba **Projeto**, botão de
  adicionar, aponte para `pcb/sentinela/sentinela.kicad_sym`. Dê o apelido
  `sentinela`.
- `Preferências → Gerenciar bibliotecas de footprints`, aba **Projeto**, aponte
  para a pasta `pcb/sentinela/sentinela.pretty`, mesmo apelido.

Aba **Projeto**, não Global: assim fica valendo só aqui.

## 1.3 Colocar as peças

`Colocar → Símbolo`, digite o nome na busca, Enter, clique onde quer. Repita.

| Quantas | Nome para buscar | O que é |
|---|---|---|
| 1 | `ESP32-DevKitV1-30P` | o ESP32 — é o da biblioteca `sentinela` |
| 2 | `Conn_01x02` | bornes de 2 vias: alimentação e buzina |
| 5 | `Conn_01x03` | bornes de 3 vias: DHT22, DS18B20, chama, LEDs, relé |
| 2 | `Conn_01x04` | bornes de 4 vias: display e botões |
| 4 | `R` | os resistores |
| 3 | `C` | os cerâmicos de 100 nF |
| 1 | `C_Polarized` | o eletrolítico de 100 µF |
| 2 | `PWR_FLAG` | explicado em 1.6 |

Deixe espaço entre eles. Com a peça selecionada: `R` gira, `M` move, `E` abre as
propriedades para escrever o valor (`220`, `4k7`, `100n`, `100u`).

**Dê nome a cada borne** no campo Valor — `Display TM1637`, `Sensor de chama`.
Daqui a um ano é isso que te diz qual é qual.

## 1.4 Ligar pelo nome, não pelo fio

Aqui está o truque que faz o desenho caber na folha. Você **não** precisa puxar
um fio do ESP32 até o borne lá do outro lado. Em vez disso:

1. puxa um fio curtinho saindo do pino, uns 7 mm (`Colocar → Fio`);
2. na ponta dele, põe um **rótulo global** (`Colocar → Rótulo global`) e escreve
   o nome da ligação.

**Dois pontos com o mesmo nome estão ligados**, mesmo em cantos opostos da
folha. É assim que se desenha placa de verdade; fio atravessando tudo só
embaralha.

Escreva o nome **exatamente igual** nos dois lados — `DISP_CLK` e `DISP_CLk` são
duas ligações diferentes, e o erro não aparece até a placa vir errada.

## 1.5 A tabela das ligações

Esta é a lista inteira. Cada linha é um nome de rótulo e todos os lugares onde
ele aparece.

| Nome do rótulo | Onde colocar |
|---|---|
| `+5V` | ESP32 `VIN` · borne alimentação pino 1 · borne relé pino 1 · `C1` pino 1 |
| `GND` | ESP32 **os dois** `GND` · pino de terra de **todos** os bornes · `C1` `C2` `C3` `C4` pino 2 |
| `+3V3` | ESP32 `3V3` · bornes display, DHT22, DS18B20 e chama no pino 1 · `R3` `R4` pino 1 · `C2` `C3` `C4` pino 1 |
| `DISP_CLK` | ESP32 `D18` · borne do display pino 3 |
| `DISP_DIO` | ESP32 `D19` · borne do display pino 4 |
| `DHT_DADO` | ESP32 `D32` · borne do DHT22 pino 2 · `R3` pino 2 |
| `TEMP_DADO` | ESP32 `D23` · borne do DS18B20 pino 2 |
| `CHAMA_DO` | ESP32 `D35` · borne da chama pino 2 · `R4` pino 2 |
| `BUZINA` | ESP32 `D25` · borne da buzina pino 1 |
| `LED_ALERTA_R` | ESP32 `D26` · `R1` pino 1 |
| `LED_ALERTA` | `R1` pino 2 · borne dos LEDs pino 1 |
| `LED_UMIDADE_R` | ESP32 `D27` · `R2` pino 1 |
| `LED_UMIDADE` | `R2` pino 2 · borne dos LEDs pino 2 |
| `BT_PRETO` | ESP32 `D13` · borne dos botões pino 1 |
| `BT_VERMELHO` | ESP32 `D33` · borne dos botões pino 2 |
| `BT_VERDE` | ESP32 `D4` · borne dos botões pino 3 |
| `RELE_IN` | ESP32 `D16_RX2` · borne do relé pino 2 |

São **17 ligações**. Os LEDs aparecem em duas linhas cada porque o resistor fica
no meio do caminho: o ESP32 entra de um lado dele, o borne sai do outro.

Os **botões não levam resistor**: eles usam o de dentro do próprio ESP32, que é
o que o firmware pede. O lado solto de cada botão vai ao terra comum, e isso
acontece lá no painel, fora da placa.

## 1.6 As duas marcas de alimentação

Ponha um `PWR_FLAG` encostado no `+5V` e outro no `GND`, cada um com um fio
curto e o rótulo do mesmo nome. Eles não existem na placa — servem só para
dizer ao verificador que essa energia **entra pelo borne**, e não sai de algum
componente. Sem eles ele reclama que o ESP32 está sendo alimentado por ninguém.

## 1.7 Marcar os pinos que ficam sobrando

O ESP32 tem 30 pinos e você usa 16. `Colocar → Marcador de não conectado` em
cada um dos 14 que sobram:

`D12` `D14` `D34` `VN_39` `VP_36` `EN` `D15` `D2` `D17_TX2` `D5` `D21` `D3_RX0`
`D1_TX0` `D22`

Sem isso o verificador reclama de cada um. Com isso ele entende que é de
propósito.

## 1.8 Conferir

`Inspecionar → Verificador de regras elétricas → Executar`.

**Tem que dar zero.** Os erros mais comuns e o que são:

| O que ele diz | O que é |
|---|---|
| pino não conectado | faltou o marcador de não conectado, ou faltou um rótulo |
| rótulo com uma ocorrência só | você escreveu o nome errado de um dos lados |
| pino de alimentação não alimentado | faltou o `PWR_FLAG` |
| ponto fora da grade | a peça foi largada fora do quadriculado — mova com a grade de 1,27 mm ligada |

## 1.9 Dizer qual peça real é cada símbolo

Agora o **footprint**: a pegada de cada componente na placa, os furos.
`Ferramentas → Atribuir footprints`, ou `E` em cada símbolo e preencher o campo.

| Peça | Footprint |
|---|---|
| ESP32 | `sentinela:ESP32-DevKitV1-30P` |
| borne de 2 vias | `TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-2-5.08_1x02_P5.08mm_Horizontal` |
| borne de 3 vias | o mesmo, trocando `-2-` por `-3-` e `1x02` por `1x03` |
| borne de 4 vias | idem, `-4-` e `1x04` |
| resistores | `Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P10.16mm_Horizontal` |
| 100 nF | `Capacitor_THT:C_Disc_D5.0mm_W2.5mm_P5.00mm` |
| 100 µF | `Capacitor_THT:CP_Radial_D6.3mm_P2.50mm` |

Esse borne Phoenix é o desenho do KRE que você tem: mesmo passo de 5,08 mm. Os
de 3 e 4 vias são os seus KRE de 2 vias encaixados lado a lado.

Salve. **Acabou a etapa 1** — e ela é a que tem decisão. O resto é braço.

---

# Etapa 2 — a placa

## 2.1 Levar o desenho para a placa

Volte à janela do projeto e abra o **editor de PCB**. Lá dentro:
`Ferramentas → Atualizar PCB a partir do esquema`.

Aparece um monte de peça empilhada com linhas finas entre elas. Cada linha fina
é uma ligação que ainda não virou trilha.

## 2.2 Desenhar o contorno da placa

Antes de posicionar, diga onde a placa acaba. Escolha a camada **`Edge.Cuts`**
na lista da direita e desenhe um retângulo (`Desenhar → Retângulo`). Comece com
**100 × 80 mm** e ajuste depois.

Ponha também quatro furos de fixação M3 nos cantos: `Colocar → Footprint`,
busque `MountingHole_3.2mm_M3`.

## 2.3 Posicionar

Arraste cada peça. As regras que valem aqui são de montagem, não de eletrônica:

- **bornes nas bordas**, com a boca do parafuso virada para fora da placa;
- **ESP32 no meio**, com o lado do cabo USB virado para onde você vai conseguir
  enfiar o cabo com a caixa aberta;
- **resistores e capacitores perto de quem eles servem** — o `R4` junto do borne
  do sensor de chama, os 100 nF colados nos bornes dos sensores;
- gire as peças (`R`) até as linhas finas pararem de se cruzar. Cada cruzamento
  que você resolve agora é uma trilha difícil a menos depois.

Não precisa ficar bonito. Precisa ficar com as linhas finas curtas e sem nó.

## 2.4 Dizer a grossura das trilhas

`Arquivo → Configuração da placa → Regras de projeto → Classes de rede`:

| | Valor |
|---|---|
| Largura de trilha | 0,3 mm |
| Afastamento | 0,25 mm |
| Via | 0,6 mm, furo 0,3 mm |

E crie uma classe à parte para `+5V`, `+3V3` e `GND` com trilha de **0,8 mm** —
alimentação pede mais cobre. Tudo isso é folga larga; nenhuma fábrica chia.

## 2.5 Passar as trilhas

Ferramenta de rotear (`Rotear → Rotear trilhas`). Clique num pino, siga a linha
fina, clique no destino.

- comece pelas **curtas e fáceis**, para ir pegando o jeito;
- **o terra fica por último** — e não se roteia à mão: veja 2.6;
- trilha de um lado só não dá conta de tudo. Quando precisar passar por baixo de
  outra, use uma **via** (duplo clique no meio do caminho) e siga pela camada de
  trás;
- `Delete` numa trilha torta e refaça. Ninguém acerta de primeira.

## 2.6 O terra é um tapete, não uma trilha

Em vez de puxar trilha para cada terra, preencha a camada de trás inteira de
cobre ligado ao `GND`:

`Desenhar → Zona de preenchimento`, escolha a camada **`B.Cu`**, escolha a rede
**`GND`**, desenhe um retângulo cobrindo a placa toda, e depois mande preencher
(`Editar → Preencher todas as zonas`).

Todo pino de terra se liga sozinho nesse tapete. É assim que se faz, e economiza
metade do trabalho.

## 2.7 Conferir de novo

`Inspecionar → Verificador de regras de design → Executar`. Tem que dar zero, e
ele avisa se sobrou alguma ligação sem trilha.

## 2.8 Mandar para a fábrica

`Arquivo → Fabricar → Arquivos de fabricação → Gerbers`. Gere os **Gerbers** e,
no mesmo lugar, o arquivo de **furação**. Junte tudo num `.zip` e é isso que
você envia — JLCPCB e PCBWay aceitam o zip direto.

Peça **2 camadas, 1,6 mm, HASL**. O mínimo são 5 placas e sai barato; o que
pesa é o frete.

---

# Antes de mandar, três conferências que valem a placa

1. **O contorno fecha?** Retângulo aberto em `Edge.Cuts` é placa cortada errado.
2. **Os furos dos bornes cabem no seu KRE?** Encoste o borne real na tela no
   tamanho 1:1 (`Ver → Zoom`), ou meça o passo com paquímetro: 5,08 mm.
3. **A serigrafia diz o que é cada borne?** Escreva `U — botão preto`,
   `F — CLK`, na camada `F.SilkS`. É a parte que mais salva tempo depois, e a
   que todo mundo esquece.
