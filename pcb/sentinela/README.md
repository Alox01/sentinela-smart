# Projeto da placa no KiCad

Abra o arquivo **`sentinela.kicad_pro`**. Ele puxa todo o resto junto.

Para olhar o desenho elétrico sem abrir programa nenhum, abra
**`esquematico.pdf`**.

## O que já está pronto

| Arquivo | O que é |
|---|---|
| `sentinela.kicad_sch` | o **desenho elétrico** — todas as ligações, conferidas uma a uma |
| `sentinela.kicad_sym` | o **símbolo** do ESP32: o desenho dele com os 30 pinos nomeados |
| `sentinela.pretty/` | a **pegada** do ESP32: onde ficam os 30 furos e de que tamanho |
| `esquematico.pdf` | o mesmo desenho elétrico, para imprimir ou olhar rápido |
| `sentinela.kicad_pro` | o projeto, que amarra tudo |

As ligações saíram do firmware e do mapa de bornes, não de memória. As 17
ligações foram listadas e conferidas pino a pino depois de prontas, e o
verificador do próprio KiCad **não apontou nenhum erro**.

Todo componente já tem a peça real escolhida — borne, resistor, capacitor e a
placa do ESP32 —, então não sobra nada para decidir nessa parte.

## O ESP32: as medidas vieram da placa que existe

É o **DOIT ESP32 DevKit V1 de 30 pinos**, e os números não foram chutados:

- o mapa em `docs/MONTAGEM_DEFINITIVA.md` diz que as barras fêmea ocupam as
  colunas `G` a `U` — **15 furos por fileira, 30 no total**;
- e que elas estão nas **linhas 12 e 22** — dez furos de 2,54 mm entre uma e
  outra, ou seja **25,4 mm entre as fileiras**;
- a ordem dos pinos foi conferida contra cada coluna que o mapa cita: `D13` no
  `I`, `D14` no `K`, `D25` no `N`, `D18` no `O` da linha 22. Bate pino a pino.

A pegada tem o nome de cada pino escrito ao lado do furo, para a placa chegar da
fábrica já dizendo o que é o quê.

## O que falta, em três passos

**1. Posicionar.** Abrir o editor de placa, mandar ele trazer os componentes do
desenho elétrico e arrastar cada um para o seu lugar. É a parte que depende da
caixa: os bornes vão nas bordas, o ESP32 no meio, os resistores perto de quem
eles servem. Não tem resposta única — tem o que fica cômodo de parafusar.

**2. Ligar.** Desenhar as trilhas de cobre que substituem os fios. O programa
mostra uma linha fina entre cada par que precisa se ligar; você passa a trilha
por cima dela. Regras já gravadas no projeto: trilha de **0,3 mm** no sinal,
**0,8 mm** na alimentação, afastamento de **0,25 mm**. É folga larga de
propósito.

**3. Conferir e exportar.** Rodar o verificador (ele reclama de trilha esquecida
ou peça encostando em peça) e gerar os arquivos que a fábrica lê.

## O que não entra nesta placa

**Rede de 220 V, nada.** Daqui saem três fios de baixa tensão até o módulo de
relé, pelo borne `J9`. Contator, fusível e fiação de força continuam no setor
separado da caixa, atrás da divisória.

## As peças

| Ref | O que é | Peça escolhida |
|---|---|---|
| `U1` | ESP32 | DOIT DevKit V1, 30 pinos, em barra fêmea |
| `J1` | alimentação 5 V | borne de 2 vias, passo 5,08 mm |
| `J2` | display TM1637 | borne de 4 vias |
| `J3` | DHT22 — umidade | borne de 3 vias |
| `J4` | DS18B20 — temperatura | borne de 3 vias |
| `J5` | sensor de chama | borne de 3 vias |
| `J6` | buzina | borne de 2 vias |
| `J7` | LEDs do painel | borne de 3 vias |
| `J8` | botões do painel | borne de 4 vias |
| `J9` | módulo de relé | borne de 3 vias |
| `R1` `R2` | 220 Ω dos dois LEDs | resistor de furo |
| `R3` | 4,7 kΩ do DHT22 | resistor de furo |
| `R4` | 4,7 kΩ do sensor de chama | resistor de furo |
| `C1` | 100 µF na entrada de 5 V | eletrolítico |
| `C2` `C3` `C4` | 100 nF nos sensores | cerâmico |

Os **bornes de 3 e 4 vias** são os KRE de 2 vias que você já tem, encaixados
lado a lado — eles deslizam e viram uma régua só, no mesmo passo de 5,08 mm.

Os **botões não têm resistor** aqui: eles usam o pull-up de dentro do próprio
ESP32, que é o que o firmware pede com `INPUT_PULLUP`.

O **`R4` é o único componente que a placa de hoje não tem.** Ele vem do próprio
`MONTAGEM_DEFINITIVA.md`: o `GPIO 35` não tem pull-up interno, e cabo do sensor
de chama rompido deixa o pino solto no ar — sem esse resistor, um cabo partido
faz o aparelho gritar incêndio sem incêndio. Se preferir deixar para depois, o
furo fica lá, vazio.

## Como este projeto foi gerado

Por um script, a partir da pinagem do firmware — não à mão. Ele está fora da
árvore, no material de trabalho da sessão; se a pinagem mudar, é mais rápido
corrigir o desenho direto no KiCad.
