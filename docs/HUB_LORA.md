# Hub LoRa — estufa fora do alcance do Wi-Fi

Projeto (02/08/2026) de um **hub**: um ESP32 com rádio LoRa, Wi-Fi e cartão SD
que recebe as leituras de estufas distantes por rádio e as repassa para a nuvem
pelas rotas que já existem.

> **Isto é projeto, não implementação.** Nenhuma linha de código foi escrita, e
> `firmware/sentinela_esp32/` **não foi tocado** — está em produção numa estufa
> em uso. O documento serve como "trabalho futuro fundamentado": mesmo que nada
> seja construído, as decisões e os porquês ficam registrados.

As seções marcadas **[campo]** são conhecimento do produtor. As **[inferência]**
são conclusões técnicas — e caem junto se a premissa cair. As **[medido]** são
contas feitas aqui, com a fórmula e os parâmetros à vista, para poderem ser
conferidas.

---

## O problema

Hoje cada aparelho fala Wi-Fi e empurra a leitura para a nuvem
(`POST /leitura`, 1×/min) e busca comandos de volta (`GET /comandos`, 1×/20 s).
Isso exige que o Wi-Fi da casa alcance a estufa. Uma estufa longe da casa fica
**fora do alcance** — e sem alcance não há leitura, não há histórico, não há
aviso de incêndio no celular.

O desenho proposto:

```
  [ estufa distante ]                      [ casa ]
   nó: sensores + botões          rádio     hub: LoRa + Wi-Fi + SD
   + rádio LoRa            ─ ─ ─ ─ ─ ─ ─>   traduz e reenvia
   (sem Wi-Fi)               915 MHz                │
                                                    │ Wi-Fi da casa
                                                    v
                                          POST /leitura (nuvem)
```

O nó continua sendo um controlador **edge-first**: sirene, visor, botões e
alarme funcionam sem rádio nenhum, exatamente como hoje. O rádio só acrescenta a
capacidade de **contar** o que está acontecendo. Se o hub morrer, a estufa
continua vigiada por quem estiver perto dela — só o celular deixa de saber.

---

## 1. Frequência — **915 MHz**, e o 433 MHz é uma armadilha

### Confirmado

No Brasil, os equipamentos de radiação restrita são regidos pela **Resolução
Anatel nº 680/2017**. Na faixa de 900 MHz há uma **peculiaridade brasileira**
que não existe nos Estados Unidos: a sub-faixa **907,5–915 MHz é reservada à
telefonia celular** e nenhum outro equipamento pode operar ali. Sobram
**902–907,5 MHz** e **915–928 MHz**.

Por isso o Brasil adota o plano **AU915-928** do LoRaWAN, e não o US915. Na
prática:

- **Compre módulo de 915 MHz** e opere entre **915 e 928 MHz** — a recomendação
  segura é ficar na janela dos canais AU915 (915,2 a 927,8 MHz);
- **Não use 902–915 MHz** só porque a folha do fabricante diz "902–928": a
  metade de baixo dessa faixa inclui os 907,5–915 MHz que são da operadora.

### O que acontece se comprar 433 MHz

Não é ilegal, e é aí que mora a armadilha — se fosse proibido, o vendedor
avisaria. A faixa **433–435 MHz é permitida** no Brasil para radiação restrita,
**mas com potência limitada a 10 mW e.i.r.p.**

Um módulo LoRa comum (RFM95/SX1276) transmite até **+20 dBm = 100 mW**. Para
ficar dentro da lei em 433 MHz seria preciso **reduzir a potência a um décimo** —
jogando fora exatamente o alcance que motivou escolher LoRa. Em 915 MHz o teto
permitido é muito maior, e o módulo pode trabalhar na potência cheia.

Some-se a isso:

1. **433 MHz e 915 MHz não se falam.** Chips diferentes (RFM96/SX1278 × RFM95/
   SX1276). Comprar um de cada = dois enfeites. Se um nó vier 433 e o hub 915,
   nada acontece e não há mensagem de erro: o rádio simplesmente não escuta;
2. **Antena errada pode queimar o módulo.** Uma antena de 433 MHz num rádio de
   915 (ou o contrário) reflete a potência de volta para o amplificador. Ligar o
   rádio **sem antena nenhuma** faz o mesmo. Regra: antena rosqueada **antes** de
   energizar, sempre;
3. **433 MHz é a faixa mais poluída do Brasil.** Controle de portão, alarme de
   carro e sensor sem fio de esteira lotam 433,92 MHz. Numa propriedade rural com
   portão automático, o rádio disputa espaço com o chaveiro do vizinho.

> **Aviso para levar à loja:** o anúncio precisa dizer **915 MHz** (ou
> **SX1276 / RFM95W 915**). Se disser 433 MHz, 470 MHz ou 868 MHz, **é outro
> produto** — 868 é Europa, 470 é China.

---

## 2. Hardware — placa integrada para o hub, módulo avulso para o nó

### O conflito de pinos, com números

O mapa de referência do protótipo (`CONFIGURACAO_ESP32.md`) usa:

| GPIO | Uso hoje |
|---|---|
| 32 | DHT22 DATA |
| 35 | Sensor de luz (entrada-apenas) |
| 13 | Botão do buzzer |
| 4 | Botão verde |
| 33 | Botão vermelho |
| 26 | LED de alerta |
| 27 | LED de umidade |
| 14 | LED de temperatura |
| 25 | Buzzer |
| 18 / 19 | Display TM1637 CLK / DIO |

A placa integrada mais comum, a **LilyGO TTGO LoRa32 T3 v1.6.1**, usa (valores
verbatim do `utilities.h` do próprio fabricante):

| Função | GPIO |
|---|---|
| Rádio SCK / MISO / MOSI / CS | 5 / 19 / 27 / 18 |
| Rádio RST / DIO0 / DIO1 / DIO2 | 23 / 26 / 33 / 32 |
| microSD MOSI / MISO / SCK / CS | 15 / 2 / 14 / 13 |
| OLED SDA / SCL | 21 / 22 |
| LED da placa | 25 |
| ADC da bateria | 35 |

**Sobrepondo os dois mapas: 9 dos 11 pinos do protótipo colidem.** As colisões
duras (não têm como contornar, porque o pino da placa está soldado ao rádio ou
ao cartão):

| Pino | Protótipo | TTGO T3 |
|---|---|---|
| 18 | Display CLK | **Rádio CS** |
| 19 | Display DIO | **Rádio MISO** |
| 27 | LED de umidade | **Rádio MOSI** |
| 26 | LED de alerta | **Rádio DIO0** (interrupção de pacote — essencial) |
| 14 | LED de temperatura | **SD SCK** |
| 13 | Botão do buzzer | **SD CS** |
| 35 | Sensor de luz | **ADC da bateria** (35 é entrada-apenas e o divisor já está fixo) |
| 33 | Botão vermelho | Rádio DIO1 (dispensável no uso básico) |
| 32 | DHT22 | Rádio DIO2 (dispensável no uso básico) |

Só **4** (botão verde) e **25** (buzzer, que passa a piscar o LED da placa junto)
sobrevivem.

### Veredito

**Hub: placa integrada TTGO LoRa32 T3 v1.6.1 — e o conflito de pinos não
existe.** O hub não tem DHT, nem display de 7 segmentos, nem botões, nem LEDs,
nem buzzer. Ele é rádio + Wi-Fi + cartão. Todos os pinos "em conflito" acima são
pinos que o hub **quer** que estejam ligados ao rádio e ao cartão. Uma placa,
um fornecedor, zero fios — e o slot de microSD e o visor OLED vêm de brinde.
Atenção só à variante: precisa ser a **T3 v1.6.1, que tem microSD**; há versões
da mesma família sem cartão.

**Nó: ESP32 atual + módulo RFM95 avulso.** Aqui a placa integrada seria o
caminho errado, porque obrigaria a **remapear 9 pinos** de uma montagem que já
funciona e já foi validada em campo. Com módulo avulso, o SPI do ESP32 é
remapeável por matriz de GPIO (não precisa ser o VSPI padrão 18/19/23/5, que é
justamente onde estão o display), e **sobra espaço sem mexer em um fio sequer**:

| Sinal do RFM95 | GPIO sugerido | Por quê |
|---|---|---|
| SCK | 22 | livre no mapa atual |
| MISO | 21 | livre |
| MOSI | 23 | livre |
| NSS (CS) | 5 | livre |
| DIO0 | 34 | livre, e **entrada-apenas serve bem** para uma linha de interrupção |
| RST | 17 | livre |

> **Ressalva:** se o ESP32 do nó for um módulo **WROVER** (com PSRAM), os GPIO
> **16 e 17 não estão livres** — a PSRAM os usa. Nesse caso troque o RST por
> **GPIO 2** (com o cuidado de ser pino de boot) ou deixe o RST amarrado ao 3V3
> por um resistor de 10 kΩ, que várias bibliotecas aceitam. O DevKit V1 comum é
> WROOM e não tem esse problema.

Para a **bancada das etapas 1 a 3**, porém, a recomendação é comprar **duas
TTGO iguais**: um par idêntico elimina "será que é o meu fio?" da lista de
suspeitos quando o rádio não conversar. A decisão de como montar o nó definitivo
vem depois, na etapa 4.

---

## 3. O quadro LoRa — 16 bytes contra 740

### Por que o JSON atual não cabe

Um push típico do firmware de hoje (`empurrarLeituraNuvem()`, com `config`
junto) tem **≈ 740 bytes**. O limite físico de um pacote LoRa (SX1276) é de
**255 bytes**. O JSON não é lento demais: ele **não cabe**, e precisaria ser
partido em três pedaços.

Airtime, pela fórmula da Semtech (BW 125 kHz, CR 4/5, preâmbulo 8, cabeçalho
explícito, CRC ligado) **[medido]**:

| Payload | SF7 | SF9 | SF10 | SF12 |
|---|---|---|---|---|
| **16 bytes** (proposto) | 51 ms | 165 ms | **330 ms** | 1.319 ms |
| 247 bytes (1 de 3 fatias do JSON) | — | — | 2.113 ms | — |

O JSON partido em três dá **~6,6 s de rádio por leitura, por nó**. A 1 leitura
por minuto isso é **11% do tempo ocupando o canal com um único nó**, e cada
fatia estoura em 5× o limite regulatório de permanência descrito abaixo. Ou
seja: não é uma questão de otimizar, é inviável.

### Limite de permanência no canal (dwell time)

O plano **AU915 não tem limite de ciclo de trabalho** (duty cycle), mas tem
**limite de permanência de 400 ms por transmissão**. Isso **elimina SF11 e
SF12**:

| SF | Airtime (16 B) | Cabe em 400 ms? | Alcance típico rural (ordem de grandeza) |
|---|---|---|---|
| 7 | 51 ms | sim | ~1–2 km |
| 8 | 93 ms | sim | ~2–3 km |
| 9 | 165 ms | sim | ~3–5 km |
| **10** | **330 ms** | **sim, no limite** | **~5–8 km** |
| 11 | 659 ms | **não** | — |
| 12 | 1.319 ms | **não** | — |

Os alcances são **[inferência]** a partir de números de fabricante, que são
medidos em linha de visada limpa. **Com vegetação, relevo ou telhado metálico no
caminho, divida por 3 a 5.** Quem decide o SF é a **etapa 2**, medindo — não
esta tabela.

**Recomendado: SF10, BW 125 kHz, CR 4/5, um canal fixo entre 915,2 e 927,8 MHz,
+20 dBm.** É o SF mais alcançador que ainda cabe nos 400 ms. Se a etapa 2 provar
que o enlace fecha com folga, cair para SF9 dobra a margem de colisão de graça.

### O formato

```
byte   0    versão do formato        (1)
byte   1    tipo de quadro           (1 = leitura, 2 = leitura de emergência)
bytes  2-4  id do nó                 (3 bytes = os mesmos 6 hex do MAC que
                                      já formam "ESP32_A1B2C3")
bytes  5-6  contador de sequência    (uint16, persistido em NVS)
bytes  7-8  temperatura ×10 em °F    (int16 — 142,5 °F vira 1425)
byte   9    umidade %                (uint8, 0–100)
bytes 10-11 ajuste de temperatura ×10(int16)
byte  12    flags                    (bit0 alertaTemperatura, bit1 alertaIncendio,
                                      bit2 perigoChama, bit3 alarmeAtivo,
                                      bit4 buzzerAtivo, bit5 modoSilencioso,
                                      bit6 leituraOk, bit7 reservado)
bytes 13-16 MIC                      (autenticação — ver decisão 4)
                                     ────
                                     17 bytes
```

Decisões embutidas nesse desenho, com o porquê:

- **Nenhum timestamp no quadro.** O nó não tem Wi-Fi, logo não tem NTP, logo não
  tem hora. Quem carimba é o **hub**, que tem relógio. Isso simplifica o nó e
  resolve o problema do cartão SD (decisão 6): existe **uma única fonte de
  tempo** no sistema;
- **Temperatura ×10 em inteiro**, não float. O firmware de hoje já arredonda para
  inteiro; ×10 dá casa decimal de sobra se um dia o DS18B20 entrar, e economiza
  2 bytes contra um float;
- **A `config` inteira ficou de fora.** O ajuste de temperatura vai porque o app
  o exibe e a política de gravação da nuvem o usa. Os timestamps de LWW **não
  vão**: sem canal de descida (decisão 5), não há LWW pelo rádio — o ajuste do
  nó só muda pelos botões dele;
- **Contador de sequência de 16 bits, gravado na NVS.** Serve para medir perda
  (é o número que vira resultado no TCC) e para recusar repetição (decisão 4).
  8 bits dariam a volta em 4 horas; 16 bits duram 45 dias. Gravar na NVS a cada N
  incrementos — não a cada um — pelo mesmo motivo que `salvarConfigSeNecessario()`
  já agrupa escritas hoje: a flash tem ciclos contados;
- **Sem campo de texto.** `aviso`, `faseAtual` e `corStatus` são **derivados** —
  o hub os recalcula a partir das flags e do ajuste, com as mesmas funções que o
  firmware de hoje tem (`avisoAtual()`, `fasePorAlvo()`, `corStatusAtual()`).
  Mandar texto pelo rádio seria pagar 60 bytes por informação que o receptor já
  sabe deduzir.

### Cadência e quantos nós cabem

**Cadência: 1 quadro/minuto**, igual ao `PUSH_INTERVAL_MS` de hoje, **mais envio
imediato na borda de alarme** — o mesmo `estadoDeAlertaMudou()` que já existe.

Duas coisas precisam entrar junto:

1. **Jitter de ±5 s no instante do envio.** Sem isso, dois nós ligados na mesma
   queda de energia bootam no mesmo instante e colidem **toda vez**, para sempre.
   É a falha mais provável de todas e a mais barata de evitar;
2. **Quadro de emergência repetido 3×**, com espaçamento aleatório de 2 a 5 s.
   Não há confirmação de recebimento (decisão 5), então a única defesa de um
   aviso de incêndio é a redundância.

Contas de colisão, ALOHA puro, SF10 (330 ms), 1 quadro/min **[medido]**:

| Nós | Ocupação do canal | Chance de um quadro se perder |
|---|---|---|
| 2 | 1,1 % | ~2 % |
| 4 | 2,2 % | ~4 % |
| 6 | 3,3 % | ~6 % |
| 10 | 5,5 % | ~10 % |
| 20 | 11 % | ~20 % |

**Até ~10 nós é confortável**, e a perda nem aparece: a nuvem só guarda **1
leitura a cada 10 min** (`storage_policy.js`), então perder 6% dos quadros de
1 min não tira um único ponto do relatório. Com o quadro de emergência repetido
3×, a chance de um incêndio não chegar a 6 nós é 0,06³ ≈ **0,02%**.

Passando de 10 nós, as saídas em ordem de preferência: cair para SF9 (metade do
airtime), depois espaçar para 1 quadro a cada 2 min, e só então pensar em um
segundo rádio no hub.

> **Restrição do receptor:** um SX1276 escuta **um canal e um SF por vez**. Todos
> os nós têm de usar o mesmo canal e o mesmo SF. Nada de "cada estufa no seu
> canal" — o hub não varre.

---

## 4. Segurança — autenticar sim, cifrar não

### A exposição, declarada

**LoRa é rádio aberto.** Quem tiver um módulo de R$ 60 e souber o canal e o SF
escuta tudo. A chave por aparelho que existe hoje autentica **HTTP** — ela não
tem efeito nenhum sobre o que trafega no ar, e reutilizá-la no rádio seria
**pior que não proteger**: um vazamento pelo rádio entregaria junto o acesso à
nuvem daquele aparelho.

Três ataques, em ordem de estrago:

| Ataque | Estrago | Vale defender? |
|---|---|---|
| **Escutar** | Alguém sabe a temperatura da estufa e que ela está curando | Não |
| **Forjar leitura** | Alarme falso de incêndio às 3h; ou o contrário, leitura "normal" mantendo o vigia de silêncio calado com a estufa realmente morta | **Sim** |
| **Repetir quadro gravado** | Mesmo estrago da forja, sem precisar saber a chave | **Sim** |

### O que fazer (cabe no prazo)

1. **MIC de 4 bytes** — AES-128-CMAC truncado sobre os bytes 0 a 12, com uma
   **chave de 128 bits por nó**, compartilhada com o hub. O ESP32 tem AES em
   hardware (mbedtls); custa microssegundos e ~2 KB de flash. 4 bytes dão 1
   chance em 4 bilhões por tentativa de forja — e como cada tentativa custa uma
   transmissão de rádio, é folgado;
2. **Recusar sequência não-nova.** O hub guarda o último contador de cada nó e
   descarta quadro com sequência igual ou menor (com janela para reordenação).
   Isso mata a repetição;
3. **Chave de rádio separada da chave HTTP.** Gerada por `esp_random()` como a
   de hoje, mas guardada em outra entrada da NVS e **nunca** enviada pela rede.
   O emparelhamento nó↔hub entra no **modo de configuração** do nó, que já existe
   e já exige presença física (3 botões + PIN no visor, v1.24.0).

### O que NÃO fazer, e por quê

- **Não implementar LoRaWAN.** Servidor de rede, join OTAA, ADR, packet
  forwarder, gateway de 8 canais. É um projeto do tamanho deste, para resolver
  problemas de escala (milhares de nós, roaming, múltiplos operadores) que aqui
  não existem;
- **Não cifrar o payload.** A confidencialidade da temperatura não vale a
  gestão de chaves e o depurar-às-cegas que ela traz. **Autenticidade é o que
  protege; sigilo é enfeite.** Se um dia interessar, AES-128-CTR sobre os bytes
  6 a 12 usando o contador de sequência como nonce é quase de graça — mas
  depois, não agora;
- **Não fazer rotação de chave pelo ar.** Trocar a chave exige ir até o nó. É
  aceitável: o nó fica na propriedade, e a mesma decisão já foi tomada para a
  chave HTTP (`CONFIGURACAO_ESP32.md`, "presença física = poder total");
- **Não colocar canal de descida** nesta versão (ver decisão 5). Comando forjado
  pelo rádio — "mude o ajuste para 200 °F", "cale a sirene" — é o pior estrago
  possível, e é justamente o que o canal de descida abriria.

### O que continua exposto, e se aceita

- **Qualquer um ao alcance lê temperatura, umidade e o estado de alarme das
  estufas**, e sabe quando a propriedade está curando fumo. Aceito;
- **Bloqueio por interferência (jamming).** Não há defesa barata contra alguém
  que transmita ruído contínuo na faixa. O sintoma, porém, **já é tratado**: o nó
  para de reportar, e o vigia de silêncio de 5 min dispara "estufa sem
  comunicação" no celular. O ataque cala o rádio, não o aviso;
- **O hub em mãos erradas** entrega as chaves de rádio de todos os nós. Mitigação
  que vem de graça: o hub usa a **chave universal** para o `POST /leitura` (o
  `auth.js` já aceita a universal nessa rota, para qualquer `idHardware`), então
  **o hub nunca precisa guardar a chave HTTP de nenhum nó**. Quem roubar o hub
  consegue empurrar leitura falsa — que é exatamente o estrago que a separação de
  credenciais de 31/07 já declarou como aceito — e **não** consegue mudar ajuste
  nem calar sirene de estufa nenhuma.

---

## 5. O nó ainda precisa de Wi-Fi? — Não, e o app quase não muda

### O que se perde quando a estufa é só LoRa

| Recurso | Hoje (Wi-Fi) | Nó só LoRa |
|---|---|---|
| Leitura ao vivo no app | LOCAL (verde) ou NUVEM (azul) | **só NUVEM** |
| Histórico e relatório | funciona | **funciona** (via hub) |
| Push de incêndio / temperatura | funciona | **funciona** (via hub) |
| Vigia de "sem comunicação" | funciona | **funciona** (via hub) |
| Mudar o ajuste pelo app, de longe | funciona (`GET /comandos`) | **não funciona** |
| Mudar o ajuste pelo app, na estufa | funciona (`POST /sincronizar` local) | **não funciona** |
| Agendamento de ajuste | funciona | **não funciona** (depende da caixa de comandos) |
| Ponte de leitura app→nuvem | funciona | não se aplica |
| Ajustar pelos botões do aparelho | funciona | **funciona** |
| Modo de configuração (3 botões) | funciona | **funciona** (é o AP do próprio nó) |

### O tamanho da mudança no app: **quase zero** — e isso é sorte, não projeto

Uma estufa que o app só enxerga pela nuvem **já é um caso previsto**. O cadastro
tem o **campo manual de `idHardware`**, criado para "estufa só de nuvem/
simulador" (`HANDOFF.md`). Uma estufa LoRa é indistinguível disso: cadastra-se
com o `idHardware` do nó e **sem endereço local**. O app tenta o local, falha,
cai para NUVEM — que é exatamente a máquina de estados de 4 posições que ele já
tem.

O que **não** funciona no app não é código faltando; é **função que deixa de
existir** porque o caminho físico não existe. Mudar o ajuste de longe exige que
alguém entregue o comando ao nó, e ninguém entrega.

Duas arestas a tratar, ambas pequenas:

1. **A tela precisa dizer que o ajuste remoto não está disponível** nesta estufa,
   em vez de aceitar o comando e ele nunca ser obedecido. Hoje o app mostraria
   "aguardando o aparelho" **para sempre**. Uma marca por estufa ("estufa por
   rádio") e o botão desabilitado com a razão à vista resolvem;
2. **Se o hub cair, todos os nós ficam mudos ao mesmo tempo** e o vigia dispara N
   notificações de "sem comunicação" simultâneas. Comportamento honesto, mas
   barulhento. Tratamento futuro: o hub se reportar como um aparelho próprio, e
   o app saber que "o hub caiu" é uma notícia só.

### O caminho que restaura tudo, e por que não agora

O hub poderia buscar `GET /comandos` de cada nó e entregar por rádio, e poderia
expor `GET /status?no=X` na rede da casa para o app voltar ao modo LOCAL. Isso
devolve o ajuste remoto e o agendamento. O preço:

- **Canal de descida** = a superfície de ataque que a decisão 4 recusou;
- O nó precisa **escutar** em janelas combinadas, e o protocolo ganha
  confirmação, retransmissão e timing — de "manda e esquece" para uma máquina de
  estados dos dois lados;
- No app, **um endereço passaria a servir várias estufas**. Hoje endereço↔estufa
  é 1:1, e a guarda criada em 29/07 (*"endereço não é identidade"*) **recusa
  ativamente** uma resposta cujo `idHardware` não bate. Essa guarda existe porque
  a ausência dela já trocou os dados de duas estufas em campo. Mexer nela é mexer
  na parte do app que mais produziu problema.

**Fica para v2, declarado.** Nesta versão: **rádio de mão única, nó→hub.**

---

## 6. O cartão SD — e como não inundar o banco de novo

### O que guarda

| Arquivo | Conteúdo | Quem lê |
|---|---|---|
| `/YYYYMMDD.dat` | Um registro por quadro recebido: hora do hub, id do nó, sequência, os 13 bytes do quadro, RSSI, SNR, e um byte de estado (`pendente` / `enviado` / `descartado`) | O próprio hub, para reenviar |
| `/radio.log` | Uma linha por quadro: hora, nó, sequência, RSSI, SNR, MIC ok/falhou | **Um humano**, com leitor de cartão — é o que prova o alcance e vira resultado no TCC |

**O que o cartão NÃO é:** não é um segundo histórico para o app ler, e não é
backup do banco. O app **nunca** fala com o cartão. Confundir isso criaria uma
terceira fonte de verdade num sistema que já tem duas.

**Por quanto tempo:** um arquivo por dia, **30 dias**, apaga o mais antigo. Um nó
a 1 quadro/min gera 1.440 registros/dia; a 32 bytes por registro são **46 KB por
nó por dia**. Seis nós = **280 KB/dia**, ~8 MB/mês, ~100 MB/ano **[medido]**. Um
cartão de 4 GB sobra.

### O perigo: o banco já foi inundado uma vez

Em 2026 a tabela `leituras` chegou a **2,7 milhões de linhas e estourou a cota de
500 MB do Supabase**, porque uma das duas vias de escrita não deduplicava. Um
cartão SD que reenvia é a mesma falha com combustível: em vez de duplicar em
tempo real, ele pode **repetir meses na velocidade da máquina**.

Ao ler o código da ingestão antes de propor qualquer coisa, apareceram **três
problemas concretos** — e o primeiro é o contrário do esperado:

**(a) O reenvio ingênuo não inunda: ele evapora.** `POST /leitura` decide gravar
com `deveSalvarLeitura({ agoraMs: Date.now() })` — a política dos 10 minutos usa
a **hora de chegada**, não a hora da leitura. Se o hub despejar 6 horas de
atraso numa rajada, os 360 registros chegam com milissegundos entre si: o
critério de intervalo nunca é satisfeito, e a nuvem responde
`{"persistido": false, "motivo": "sem_mudanca_relevante"}` para quase todos. O
hub veria "sucesso", apagaria o cartão, e **o buraco no histórico continuaria
lá**.

**(b) O conserto óbvio é o que reabre a inundação.** Trocar `agoraMs` pelo
`timestampLeitura` do payload faz o backfill funcionar — e torna a ingestão
**não-idempotente**. Não há restrição de unicidade em `leituras`. Se o hub não
tiver certeza de que o envio chegou (o Render hiberna no plano gratuito; um 502
ou um timeout são rotina), ele reenvia — e cada reenvio insere tudo de novo.

**(c) Independente de cota: o reenvio dispara alarme falso.** A rota alimenta
`estado.registrarLeituraAoVivo()`, que **sobrescreve o `timestampLeitura` com a
hora de chegada**, e chama `alertas.avaliarAlertas()`, que notifica na **borda de
subida**. Uma leitura de incêndio de 3 horas atrás, reenviada, **toca alarme no
celular agora** — com som de alarme, no canal que fura o silencioso — e coloca
um valor velho na tela como se fosse ao vivo.

### Como evitar, em quatro partes

1. **Rota separada para atraso.** `POST /leitura/lote` (ou `historico: true` no
   `/leitura`): **nunca** toca o estado ao vivo, **nunca** avalia alertas, e
   deduplica pelo `timestampLeitura` do próprio registro. Resolve (a) e (c) de
   uma vez, e — importante — **não muda o comportamento da rota que está em
   produção**;
2. **Idempotência no banco, que é a única defesa que não depende de ninguém
   acertar.** Índice único em `(dispositivo_id, timestamp_origem_ms)` +
   `ON CONFLICT DO NOTHING`. A coluna `timestamp_origem_ms` **já existe**. Com
   isso, reenviar o mesmo arquivo dez vezes insere as linhas **uma vez**, e a
   pergunta "será que já subiu?" deixa de ser perigosa;
3. **O hub aplica a política de 10 minutos ANTES de enviar, não depois.** Grava
   tudo no cartão (é barato) mas sobe só o que a nuvem guardaria: 1 a cada
   10 min, mais as bordas de alarme e as mudanças de ajuste — a mesma regra de
   `storage_policy.js`, reimplementada no hub. Uma queda de 6 horas vira **~36
   linhas, não 360**;
4. **Cintos extras:** o registro só é marcado `enviado` **depois de um 200**, e a
   marca vai no cartão (reinício do hub não reenvia o que já subiu); o backfill
   sobe **devagar**, em lotes pequenos e espaçados, para não parecer um ataque
   nem estourar o rate-limit de 180/min; e há um **teto de 7 dias** — atraso mais
   velho que isso fica no cartão para um humano decidir, porque uma semana de
   silêncio é um problema operacional, não um caso de reenvio automático.

> As mudanças 1 e 2 são **no servidor**, não no firmware em produção. Elas têm
> etapa própria no plano e podem ser testadas sozinhas, sem rádio nenhum.

---

## Plano por etapas

Cada etapa é testável na bancada, sozinha, **sem tocar no que já funciona**. A
ordem não é negociável: cada uma remove uma classe de suspeito antes da
seguinte. A regra é sempre a mesma — **quando algo não funcionar na etapa N, a
causa está na etapa N**, porque as anteriores já foram provadas.

Código novo vai em pasta nova: `firmware/sentinela_lora/no/` e
`firmware/sentinela_lora/hub/`. `firmware/sentinela_esp32/` **não é tocado em
nenhuma etapa**.

### Etapa 0 — comprar e conferir

Antena rosqueada **antes** de energizar, nas duas placas. Confirmar no chip ou no
silk da placa que é **SX1276/915 MHz**. Rodar o exemplo de fábrica só para ver o
OLED acender.

**Prova:** as placas estão vivas e são o que o anúncio dizia.
**Se pular:** você vai passar a etapa 1 depurando software com um rádio de
433 MHz na mão.

### Etapa 1 — dois módulos dizendo "oi"

O mais burro possível. Placa A manda `"oi 1"`, `"oi 2"`, … a cada 2 s. Placa B
imprime no Serial o que chegou, com **RSSI e SNR**. Uma sala, um metro de
distância.

**Prova:** frequência, SF, largura de banda e palavra de sincronismo batem nos
dois lados; as bibliotecas estão certas; as antenas funcionam.
**Se pular:** todo problema posterior vira "é o rádio ou é o meu código?".

### Etapa 2 — a caminhada que decide o projeto

Mesmo esqueleto da etapa 1. Placa A numa bateria/power bank, **dentro da estufa
distante, na posição real** (dentro da caixa, na altura real, com o telhado real
por cima). Placa B na casa, onde o hub vai morar. Anotar **RSSI, SNR e quantos
dos 100 pacotes chegaram**, repetindo para **SF7, SF9 e SF10**.

**Prova:** que o enlace existe na distância real, com os obstáculos reais — e
**qual SF usar**. Sai daqui a tabela que vira resultado no TCC.
**Se pular:** você pode construir o sistema inteiro para descobrir no fim que o
morro no meio do caminho não deixa passar.

> **Esta é a etapa em que o projeto pode morrer, e é por isso que ela vem antes
> de comprar mais qualquer coisa.** Se nem SF10 fechar, as saídas são antena
> externa com ganho e altura, um repetidor no meio, ou desistir do rádio.

### Etapa 3 — o quadro de verdade

Nó manda o quadro binário de 17 bytes com valores **inventados** (temperatura
subindo em rampa, flags alternando). Hub decodifica e imprime os campos.
Sequência, contador de perdidos, jitter de ±5 s.

**Prova:** o formato, o empacotamento, o desempacotamento e a contagem de perda —
sem sensor e sem Wi-Fi no caminho.

### Etapa 4 — um nó de verdade

Firmware novo em `firmware/sentinela_lora/no/`, lendo um sensor real e enviando o
quadro. Pode começar copiando só a parte de leitura do firmware de produção — mas
**é cópia, não alteração**.

**Prova:** o caminho sensor → quadro. Comparar lado a lado com o aparelho de
produção lendo o mesmo ambiente: os números têm de bater.

### Etapa 5 — a autenticação, com prova de que funciona

Acrescenta o MIC de 4 bytes e a recusa de sequência repetida. Dois testes
negativos, que são o que dá valor à seção de segurança do TCC:

- **Forja:** uma terceira placa manda um quadro bem formado com a chave errada →
  o hub **recusa** e conta no log;
- **Repetição:** grave um quadro válido e reenvie → o hub **recusa** por
  sequência.

**Prova:** que a afirmação "o rádio é autenticado" tem evidência, e não é só uma
frase.

### Etapa 6 — o servidor aprende a receber atraso

**Sem rádio nenhum.** No `estufa_server`: a rota de lote, o índice único em
`(dispositivo_id, timestamp_origem_ms)`, e testes que subam o **mesmo lote duas
vezes** e verifiquem que a contagem de linhas **não muda**. Mais um teste de que
a rota de lote **não** mexe no estado ao vivo e **não** dispara push.

**Prova:** que o backfill é idempotente **antes** de existir alguém capaz de
gerar backfill.
**Se pular:** a etapa 8 é onde o banco inunda pela segunda vez.

### Etapa 7 — o hub traduz e sobe

Hub recebe, converte o quadro no JSON do `CONTRATO_API.md` e chama
`POST /leitura` — **contra o servidor local** (`EXECUCAO_LOCAL.md`), com um
`idHardware` inventado. Nunca contra produção.

**Prova:** a tradução quadro→contrato, e que a nuvem aceita sem enxergar
diferença entre um nó por rádio e um ESP32 por Wi-Fi.

### Etapa 8 — o cartão, e o teste que importa

Hub grava tudo no SD. Depois: **tirar a internet do hub por 1 hora** com o nó
transmitindo, conferir o arquivo crescendo; **devolver a internet** e ver o
backfill subir pela rota de lote. Então o teste que fecha a decisão 6: **reenviar
o mesmo arquivo de propósito** e conferir que a contagem de linhas não mudou.

**Prova:** o buffer, o reenvio, e a idempotência ponta a ponta.

### Etapa 9 — a nuvem de verdade, um nó só

Tudo junto contra o Render, com um `idHardware` de teste. **Olhar a contagem de
linhas do banco antes e depois de 24 h** e conferir contra o esperado (~144
linhas/dia com a política de 10 min). Só depois disso, um segundo nó.

**Prova:** que o sistema completo não engorda o banco.

### Etapa 10 — caixa, energia, antena, e uma semana quieto

Montagem final, alimentação, caixa vedada, antena posicionada. Sete dias rodando
sem ninguém mexer. Métricas do log de rádio: quadros esperados × recebidos,
RSSI mínimo, maior silêncio.

**Prova:** que aguenta a temporada — que é o único critério que interessa ao
produtor.

---

## Lista de compras

### Pedir

| Item | Qtd | Observação |
|---|---|---|
| **LilyGO TTGO LoRa32 T3 v1.6.1, 915 MHz** | 2 | Tem de ser a versão **com slot microSD**. Traz ESP32 + SX1276 + OLED + SD numa placa. Uma vira o hub; a outra é a parceira das etapas 1–3 |
| **Antena 915 MHz** com o conector da placa | 2–3 | Confirmar **SMA × IPEX/u.FL**. A placa costuma vir com um rabicho u.FL→SMA e uma antena mola. Comprar uma sobressalente |
| **microSD 4 GB ou 8 GB, classe 10** | 2 | Formatado em **FAT32**. Duas para poder trocar sem parar o hub |
| **Módulo RFM95W 915 MHz** (breakout com regulador 3V3) | 1–2 | Só a partir da etapa 4, para montar o nó sobre o ESP32 que já existe |
| Fonte 5 V ≥ 1 A + caixa vedada (IP54 ou melhor) | 1 conj. | Etapa 10 |
| Cabo/pigtail u.FL→SMA sobressalente | 1 | O u.FL é frágil e quebra em bancada |

**Só se a etapa 2 mostrar que o enlace está apertado:** antena externa de fibra
915 MHz, 5–8 dBi, com cabo curto e de baixa perda. Não comprar antes — cabo longo
e barato come mais ganho do que a antena entrega.

### NÃO pedir

| Não comprar | Por quê |
|---|---|
| **Qualquer módulo 433 MHz** (RFM96, SX1278, "LoRa 433") | Não fala com 915. E, no Brasil, 433 MHz é limitado a **10 mW** — um décimo da potência, exatamente o alcance que se quer |
| **868 MHz (Europa) ou 470 MHz (China)** | Faixa errada para o Brasil |
| **Gateway LoRaWAN** (RAK, Dragino, concentrador de 8 canais) | Centenas de reais para resolver um problema de escala que não existe com 6 nós. Este projeto **não usa LoRaWAN** — não há servidor de rede |
| **NRF24L01, APC220, HC-12, "rádio 433 de portão"** | Outra tecnologia. Não é LoRa e não tem o alcance |
| **Módulo "LoRa" sem o nome do chip no anúncio** | Muito módulo barato de 433 MHz é ASK/OOK vendido como LoRa. O anúncio tem de dizer **SX1276** ou **RFM95** |
| **Cartão de 32 GB ou mais** | Custa mais, tende a vir exFAT (que a biblioteca não lê) e o projeto usa 100 MB por ano |
| **Placa sem antena "para economizar"** | Ligar rádio sem antena danifica o amplificador |
| **6 placas de uma vez** | Comprar em quantidade antes da **etapa 2** é apostar num alcance que ainda não foi medido |

---

## Perguntas para o produtor

Estas mudam o projeto de verdade, e nenhuma pode ser arbitrada daqui:

1. **Qual a distância entre a casa (onde ficaria o hub) e a estufa mais
   distante?** Muda o SF, muda a antena, e muda se o projeto é viável. Ordem de
   grandeza basta: 500 m? 2 km? 5 km?
2. **O que tem no meio do caminho?** Morro, mata fechada, galpão de telha
   metálica, outro prédio? Vegetação densa e relevo custam muito mais que
   distância limpa — 1 km com um morro no meio é pior que 5 km de campo aberto.
3. **Dá para ver a estufa da casa?** Linha de visada muda tudo. E dá para pôr a
   antena do hub alto (telhado, caixa d'água, mastro)? **Altura vale mais que
   ganho de antena.**
4. **Quantas estufas, no futuro?** Duas ou vinte muda a cadência e a conta de
   colisão (decisão 3). Vinte também muda a resposta sobre um segundo hub.
5. **A estufa distante tem energia elétrica?** Ela tem motor de circulação, então
   presumivelmente sim **[inferência]** — mas se algum ponto for sem rede, o nó
   precisa de bateria/solar, e aí a cadência de 1 min e o SF10 são caros demais.
6. **A casa tem Wi-Fi estável onde o hub ficaria?** O hub precisa de Wi-Fi e de
   energia contínua. Se o melhor ponto de rádio (alto, com visada) não é o melhor
   ponto de Wi-Fi, os dois têm de ser conciliados antes de furar parede.
7. **Existe portão automático ou alarme sem fio na propriedade?** Não impede
   nada em 915 MHz, mas é bom saber antes de investigar interferência.

---

## O que este documento não cobre

- Alimentação por bateria/solar e cálculo de consumo do nó — só faz sentido
  depois da pergunta 5;
- Repetidor LoRa (nó que retransmite), caso a etapa 2 reprove o enlace direto;
- Canal de descida hub→nó, que devolveria ajuste remoto e agendamento (v2,
  decisão 5);
- Homologação Anatel do conjunto montado. Módulo certificado usado em projeto
  próprio de uso privado é uma situação diferente de produto colocado à venda —
  se a `VIABILIDADE_COMERCIAL.md` um dia virar realidade, isso precisa ser
  respondido por quem entende do assunto, não por este documento.
