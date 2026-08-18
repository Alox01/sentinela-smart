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

| O que buscar | Especificação | Qtd |
|---|---|---|
| Placa ilhada / perfurada (face simples) | **9 × 15 cm**, furos 2,54 mm | 1 |
| Barra de pinos **fêmea** 2,54 mm | tira de 1×40, para cortar | 2 |
| Borne KRE 2 vias, 5,08 mm (encaixável) | ver divisão abaixo | 12 |
| Resistor 4,7 kΩ 1/4 W | pull-up do DHT22 | 1 |
| Resistor 220 Ω 1/4 W | um por LED | 3 |
| Fio rígido 22 AWG | ligações na placa | 1 rolo |
| Cabo flexível 22 AWG, duas cores | até os componentes do painel | 1 rolo |
| Prensa-cabo (glândula) com porca | do diâmetro do cabo usado | 2–3 |
| Respiro de membrana para caixa | mantém o IP67 e deixa vapor sair | 1 |
| Sílica-gel em saquinho | dentro da caixa | 2 |

**Os 12 bornes** viram: alimentação (2 vias), buzina (2), DHT22 (3), chama (3),
display (4), botões (4 — três sinais e o terra comum), LEDs (4 — idem). O KRE
encaixa lateralmente, então comprar só os de 2 vias e juntar dá qualquer largura.

**A barra fêmea:** conte os pinos do ESP32 antes. Os comuns são 30 (15 por lado)
ou 38 (19 por lado); duas tiras de 40 cobrem os dois casos.

## Jumpers: nenhum

Jumper é **o mesmo contato por pressão do protoboard**, num invólucro melhor.
Levá-lo para a montagem final leva o problema junto.

Use **borne de parafuso e fio**: aperta, não solta com vibração, e permite trocar
um sensor com chave de fenda no meio da estufada.

A única exceção é a **barra fêmea do ESP32**, e ela se justifica: o módulo
precisa poder sair se queimar, é encaixe firme e ninguém mexe nele depois de
montado. Soldar o ESP32 direto significa perder a placa junto com ele.

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

**Ele não substitui o DHT22** — não mede umidade, e a umidade é gravada,
desenhada no gráfico e exportada no PDF e no CSV. Os dois juntos põem a medida
que dispara alarme no sensor robusto e deixam a umidade, que por decisão de
projeto **não** alarma, no sensor mais frágil.

Alternativa numa peça só: **SHT31** (temperatura e umidade, −40 a +125 °C, I²C).
Resolve tudo, mas não é sonda com cabo e custa mais.

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
