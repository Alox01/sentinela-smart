# Da placa ilhada para a PCB

## O motivo é medido, não estético

O que falha nesta montagem não é "solda ruim" em geral. É um tipo só: **junta de
superfície** — fio soldado por cima de uma junta que já existia, sem furo
segurando. Ela é fraca por dois motivos somados: o fio fica grudado na
superfície, sem âncora mecânica, e reaquecer estanho velho sem fluxo novo dá uma
liga fosca e quebradiça.

Três ocorrências registradas, em datas diferentes:

| Quando | O que soltou | Como apareceu |
|---|---|---|
| 09/09/2026 | 3V3 → barramento | visor apagado, umidade em 0 e temperatura inválida **juntos** |
| 09/09/2026 | ESP32 → display | só o visor apagado |
| 28/10–03/11/2026 | `D18`, `D19` e o terra do sensor de chama | visor apagando sozinho e sensor de chama oscilando |

**Numa PCB essas juntas deixam de existir**: a trilha de cobre *é* o pulo. O que
sobra para soldar são bornes e barra de pinos, em **furo metalizado**, que prende
mecanicamente além de eletricamente. A solda não some — some a solda frágil.

## Medir antes de abrir o programa

Duas medidas decidem se a placa chega útil ou vira lixo:

1. **Quantos pinos tem o ESP32** — 30 ou 36. Conte, não estime.
2. **A distância entre as duas fileiras**, de centro a centro. As placas de
   desenvolvimento vêm em larguras diferentes (22,86 mm, 25,4 mm e 27,94 mm são
   as comuns), e **o footprint errado é uma placa que não encaixa**. Medir com
   régua sobre os furos da barra fêmea atual resolve.

O passo da barra é 2,54 mm e o dos bornes KRE é 5,08 mm — esses dois já são
conhecidos e não precisam de medição.

## A netlist — as 15 redes

Fonte: `firmware/sentinela_esp32/sentinela_esp32.ino` e o mapa de bornes do
`MONTAGEM_DEFINITIVA.md`. A coluna da direita é só para conferência contra o
aparelho de hoje.

| Rede | Pino | Vai para | Borne hoje |
|---|---|---|---|
| `+5V` | `VIN` | entrada de alimentação, `VCC` do módulo de relé | cima `A` |
| `GND` | `GND` | terra de tudo | cima `C`, `H`, `R`, `B₂` / baixo `C`, `K`, `Z` |
| `+3V3` | `3V3` | display, DHT22, sensor de chama, DS18B20 | baixo `A`, `M`, `R`, `W` |
| `DISP_CLK` | `D18` | `CLK` do display | baixo `F` |
| `DISP_DIO` | `D19` | `DIO` do display | baixo `H` |
| `DHT_DADO` | `D32` | dado do DHT22, com 4,7 kΩ para `+3V3` | baixo `P` |
| `TEMP_DADO` | `D23` | dado do DS18B20, com 4,7 kΩ para `+3V3` | baixo `B₂` |
| `CHAMA_DO` | `D35` | `DO` do sensor de chama, **com 4,7 kΩ para `+3V3`** | baixo `U` |
| `BUZINA` | `D25` | positivo da buzina | cima `F` |
| `LED_ALERTA` | `D26` | LED de alerta, via 220 Ω | cima `M` |
| `LED_UMIDADE` | `D27` | LED de umidade, via 220 Ω | cima `P` |
| `BT_PRETO` | `D13` | botão do buzzer, outro lado em `GND` | cima `U` |
| `BT_VERMELHO` | `D33` | botão vermelho, outro lado em `GND` | cima `W` |
| `BT_VERDE` | `D4` | botão verde, outro lado em `GND` | cima `Z` |
| `RELE_IN` | `D16` | entrada do módulo de relé | *soldado direto hoje* |

Os três botões usam o pull-up **interno** do ESP32 (`INPUT_PULLUP`): não levam
resistor na placa, e o lado livre vai a terra.

**O `D14` não entra.** Ele era o LED de controle de temperatura, que saiu em
09/09/2026; e ele emite pulso PWM durante o boot, o que o desqualifica para
acionar qualquer coisa. O relé está no `D16` justamente porque nasce baixo no
reset.

## O que a PCB ganha que a placa de hoje não tem

| Entra | Por quê |
|---|---|
| **4,7 kΩ em `D35`** | o `GPIO 35` não tem pull-up interno. Cabo do sensor de chama rompido deixa o pino flutuando e o aparelho grita incêndio sem incêndio. Com o resistor, a falha fica silenciosa em vez de falsa |
| **100 nF em cada conector de sensor** | cinco metros de cabo fazem a alimentação balançar na ponta a cada transmissão de Wi-Fi ou toque de buzina |
| **100 µF na entrada de 5 V** | segura a trilha durante o pico de transmissão e no chaveamento do contator |
| **Borne para o módulo de relé** | hoje não sobrou via, e os três fios dele iriam soldados direto. Na PCB é um KRE de 3 vias e pronto |
| **Furos M3 nos quatro cantos** | para os espaçadores de nylon, que é o que mantém a face de cobre longe de tudo |
| **Serigrafia com o nome de cada borne** | `U — botão preto`, `F — CLK`. É a tabela de montagem impressa na própria placa; daqui a dois anos, com a caixa aberta na estufa, ninguém vai procurar documento |

## Regras de desenho com folga larga

Nada aqui chega perto do mínimo de qualquer fábrica — é de propósito, porque
trilha no limite é defeito que só aparece depois de fabricada.

| Parâmetro | Valor |
|---|---|
| Camadas | 2 |
| Espessura | 1,6 mm |
| Acabamento | HASL |
| Trilha de sinal | 0,3 mm |
| Trilha de alimentação | 0,8 mm |
| Isolamento | 0,25 mm |
| Via | 0,6 mm externo / 0,3 mm furo |
| Terra | polígono preenchido nas duas faces |

## O que não vai nesta placa

**Rede de 220 V, nada.** O contator, o fusível e a fiação de força continuam no
setor separado da caixa, atrás da divisória. Desta placa saem **três fios de
baixa tensão** até o módulo de relé, e é só. Misturar os dois numa PCB de
2 camadas exigiria ilha de isolamento fresada e recuo de 6 a 8 mm — trabalho que
não compensa quando o módulo de relé pronto já faz essa separação por dentro.

## O projeto já existe

Está em **`pcb/sentinela/`**, feito no KiCad. Abra `sentinela.kicad_pro`; para
só olhar o desenho elétrico, `esquematico.pdf`.

O esquemático está pronto e conferido — as 17 ligações foram listadas pino a
pino depois de geradas, e o verificador do KiCad não aponta nada. O símbolo e a
pegada do ESP32 foram feitos com as medidas tiradas deste documento: colunas `G`
a `U` dão 15 pinos por fileira, linhas 12 e 22 dão 25,4 mm entre elas.

Falta o posicionamento e o roteamento, que são trabalho de tela. O
`pcb/sentinela/README.md` explica os três passos sem jargão.
