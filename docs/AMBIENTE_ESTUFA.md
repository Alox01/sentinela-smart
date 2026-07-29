# Ambiente da estufa e instrumentação

Descrição do ambiente real onde o aparelho vai operar, contada pelo autor
(produtor da região) em jul/2026, mais as consequências de engenharia que ela
impõe ao projeto.

> **Por que este documento existe:** decisões de hardware e de firmware
> (limiares, escolha de sensor, posição de instalação) só fazem sentido contra o
> processo real. Sem isso registrado, cada retomada recomeça perguntando as
> mesmas coisas.

As seções marcadas **[campo]** são conhecimento do autor sobre a prática real.
As marcadas **[inferência]** são conclusões técnicas tiradas dele — e podem
estar erradas se a premissa estiver.

---

## 1. Tipo de estufa **[campo]**

Estufa de **cura flue-cured (Virginia)**, com **ar forçado** — o modelo
predominante na região. Não é a estufa convencional de convecção natural.

- O fumo fica em **grades** (algumas do tipo **grampo**), organizadas em
  **estaleiros** sobrepostos;
- A **fornalha fica numa cabine separada**, dividida do fumo por uma parede;
- Os **motores de circulação** ficam na laje ou na parede, dentro da estufa;
- O fogo **nunca toca a folha** — o ar passa pelo trocador, não pela combustão.

### Fluxo de ar

```
        [ CABINE DA FORNALHA ]  |  [ CÂMARA DO FUMO ]
                                |
   entrada de ar (em cima)  <---|--- ar que voltou da massa (úmido, mais frio)
                                |
   saída de ar (embaixo)    --->|--- ar quente e seco entra na massa
                                |
                              parede
```

O motor puxa o ar de cima e devolve por baixo. O ar quente sobe atravessando as
grades, tira água da folha, e volta para a cabine pela abertura superior.

### Renovação de ar (controle de umidade) **[campo]**

Para tirar umidade, **entra ar de fora** e o **ar úmido é expulso por outro
ponto**. A posição dessas aberturas **varia conforme o modelo** de estufa.

### Regime de funcionamento **[campo]**

Ponto importante, e contraintuitivo:

| Equipamento | Comportamento |
|---|---|
| **Motor de circulação** | **Ligado o tempo todo**, para ventilar a estufa |
| **Soprador do cinzeiro** | **Liga e desliga** conforme a fornalha precisa esquentar |

Ou seja, **quem modula o calor é o soprador da combustão**, não o ventilador de
circulação. Qualquer lógica futura de atuação (relé) precisa saber disso: cortar
o ventilador não abaixa a temperatura — só para a homogeneização.

---

## 2. Onde os sensores ficam **[campo]**

A prática usa **dois pontos distintos**, e não um só:

| Grandeza | Posição |
|---|---|
| **Temperatura** | Entre o solo e a primeira grade, a **pouco mais de 1 m**, **logo após a saída de ar quente e seco** |
| **Umidade relativa** | Entre o **primeiro e o segundo estaleiro** de grade, a **2–3 m da parede** que separa o fumo da fornalha |

### Por que são dois lugares **[inferência]**

Eles medem coisas diferentes, e ambas importam:

- A **temperatura na entrada** é o que a fornalha está entregando — é o ponto de
  controle que o produtor conhece e ajusta;
- A **umidade dentro da massa** é o que a folha está soltando — é o processo
  acontecendo.

O ar que retorna é mais frio e muito mais úmido que o que entrou. **A diferença
entre os dois é a medida do processo:** quando ela diminui, a folha está parando
de largar água, o que sinaliza virada de fase.

---

## 3. Temperaturas de trabalho **[campo]**

- **Máxima usada: ~165 °F.** Acima disso o autor considera arriscado, e é o que
  a maioria dos produtores pratica;
- As fases seguem a tabela já implementada em `logica.js` (amarelação,
  murchamento, fixação da cor, secagem da folha, secagem do talo).

### Consequência: o limiar de incêndio está apertado **[inferência]**

O firmware trata como risco de incêndio a temperatura acima de **175 °F** — ou
de **ajuste + 5 °F**, quando o ajuste passa de 170 °F (`limiteFogoF()`). Até a
v1.16.0 o firmware usava 175 fixo enquanto o servidor já acompanhava o ajuste,
e os dois **discordavam**: com ajuste em 172 °F, o aparelho alarmava aos 175 e a
nuvem só aos 177. Alinhados na v1.17.0. Esse alerta **não pode ser desligado** — só silenciado
por 10 min, que voltam sozinhos (v1.14.0) — e dispara push
com som de alarme.

Com a máxima de trabalho em 165 °F, sobram **apenas 10 °F** de folga — e o
sensor de temperatura fica **no ar mais quente da estufa**, logo na saída, antes
de perder calor para o fumo. Risco real de **alarme falso na secagem do talo**,
de madrugada, sem o produtor poder silenciar.

**Velocidade de subida foi considerada e descartada** (29/07/2026): fogo esquenta
rápido, mas a fornalha atiçada também — jogar lenha e abrir o registro sobe a
temperatura depressa e de forma legítima. O critério não separa as duas
situações, só troca um tipo de alarme falso por outro.

Cogitou-se então exigir que a condição se **sustentasse por N minutos** (o pico
de quem atiçou volta; fogo não). Também descartado, e pelo produtor: N depende
da lenha e do clima, e não existe constante que sirva.

**Pendente decidir:** nada, por enquanto — e de propósito. O alarme falso ainda
é **inferência**, não observação. Uma estufada acompanhada diz se ele acontece
de verdade; se não acontecer, o limiar relativo ao ajuste já resolve, e nenhum
mecanismo novo precisa existir. O que anotar durante a estufada: **quanto a
temperatura passa do ajuste depois de atiçar, e quanto tempo leva para assentar**.

---

## 4. Instalação prevista **[campo]**

- O aparelho atual tem **um sensor só porque é protótipo de teste**;
- A versão final terá **dois sensores**, nos dois pontos acima;
- **Ambos ficarão longe do aparelho**, ligados por **cabo longo**;
- Requisito explícito do autor: o sensor de temperatura **não pode trabalhar no
  limite** — precisa de margem para não estragar — e ambos precisam **suportar a
  umidade** de dentro da estufa.

---

## 5. Por que o DHT22 não serve para a versão final **[inferência]**

O DHT22 do protótipo falha nos três requisitos de uma vez:

| Requisito | DHT22 |
|---|---|
| Margem de temperatura | Teto de **80 °C (176 °F)**. Com 165 °F (74 °C) no ponto mais quente, trabalha **no limite** |
| Resistência à umidade | Elemento **aberto por necessidade** — é o que estraga primeiro |
| Cabo longo | Protocolo de **um fio com temporização rígida**; perde confiabilidade em poucos metros |

Some-se a isso o problema estrutural: o DHT22 mede as duas grandezas **no mesmo
ponto**, mas a prática exige **dois pontos**. Com um sensor só, uma das leituras
sempre vem do lugar errado — no ponto quente a umidade lida é a do ar seco
recém-aquecido; no ponto de umidade a temperatura é a de depois da massa.

---

## 6. Direção recomendada **[inferência]**

### Temperatura: **DS18B20, versão sonda estanque**

- **Faixa até 125 °C** contra 74 °C de uso — mais de 50 °C de margem, que atende
  ao "não quero no limite";
- **Cápsula de aço inox selada com cabo**: a umidade não alcança o elemento;
- **1-Wire, digital** — feito para cabo longo (dezenas de metros com pull-up de
  4,7 kΩ, de preferência par trançado);
- Barato, biblioteca trivial, e vários podem dividir o mesmo pino se um dia
  interessar medir entrada **e** retorno.

Termopar tipo K seria **exagero** para 74 °C — só se justificaria em
temperaturas bem mais altas.

### Umidade: cabo de 5 m decide (fatos do autor, jul/2026)

Fechado com o contexto do autor: **só umidade** nesse ponto (temperatura é o
DS18B20 à parte); sensor **entre duas camadas de fumo**, abrigado do sopro
direto da fornalha (ponto mais frio e calmo — bom para o elemento); cabo de
**~5 m, não-blindado**; e o galpão tem **motores** (ruído elétrico).

A 5 m, **I2C não é confiável** — esse é o muro que reprova o SHT31 "cru". Sobram
duas opções, e a escolha é **dinheiro × durabilidade** (o autor pediu **as duas
registradas**):

| Opção | 5 m? | Ruído/motor | Durabilidade | Custo | Firmware |
|---|---|---|---|---|---|
| **Sonda RS485/Modbus** ⭐ | sim (feito p/ isso) | **imune** (sinal diferencial) | alta (industrial; provável elemento SHT dentro) | sonda ~R$80–250 + MAX485 ~R$5 | Modbus |
| **SHT31 + extensor I2C** (P82B715) | sim, com 2 chips | melhora, **não imune** | média-alta (elemento SHT, com aquecedor anti-condensação) | SHT31 + ~R$10 | I2C normal |

**Recomendado: RS485.** O autor pediu que **dure a temporada sem trocar**; num
ambiente úmido, quente e com motor, a 5 m sem blindagem, é a única que casa tudo
sem compromisso. O custo maior compra não voltar ao galpão no meio da estufada.

**Meio-termo: SHT31 + extensor P82B715.** Mantém o ótimo elemento SHT, custa bem
menos, resolve a distância. Preço: menos imune a ruído — **compensar** passando
o cabo **longe dos cabos de motor** e usando **par trançado**. Aposta razoável,
não gambiarra.

### Ressalvas (valem para as duas opções)

- **5V não resolve nada aqui.** Nem o DHT22-5V nem o SHT31-5V vencem os 5 m: o
  problema é a **interface** (fio único com temporização / I2C), não a tensão.
  O datasheet do DHT22 até promete 20 m, mas em laboratório — no galpão com motor
  e cabo não-blindado, dá **erro intermitente**;
- **Roteamento do cabo:** o que corrompe o sinal é correr **junto do cabo de
  força do motor**, não o ar. Separar sempre; par trançado ajuda;
- **Ar precisa alcançar o elemento:** entre folhas muito compactas ele lê o
  microclima da massa (provavelmente o desejado), mas precisa de **alguma troca
  de ar** — daí a carcaça ranhurada dos sensores comerciais;
- **DHT22 descartado** (§5): teto de 80 °C (perto dos 74 °C de uso) e elemento
  exposto que estraga no úmido. Só serviria como umidade "descartável" de
  protótipo;
- **SHT31 cru descartado** a 5 m: I2C não atravessa; só com extensor ou MCU local
  (que seria construir uma sonda RS485 à mão).

### Uma folga a favor da durabilidade **[inferência]**

Na cura flue-cured os dois extremos **não coincidem**: a amarelação é muito
úmida mas relativamente fria; a secagem do talo é muito quente mas seca. O
sensor de umidade **nunca enfrenta 74 °C com 100 % de UR ao mesmo tempo** — o
que amplia bastante a vida útil.

---

## 7. Resolvido / em aberto

**Resolvido (fotos e conversa, jul/2026):**

- ✅ **Cabo ~5 m, não-blindado** — fecha a escolha da umidade (RS485 ou SHT31 +
  extensor; §6);
- ✅ **Sensores comerciais são analógicos:** temperatura = provável **termistor
  NTC** (cabo 2 fios, ponta selada); umidade = **sonda dedicada em carcaça
  ranhurada**, seca (não é bulbo úmido). Confirma por que a indústria evita
  digital de cabo curto — analógico/diferencial tolera cabo e ruído;
- ✅ **Umidade é UR direta**, não bulbo úmido (o sensor branco não usa pano
  molhado) — encerra a dúvida da §8.

**Em aberto:**

1. **Onde a caixa do aparelho será montada** (a 5 m do sensor de umidade, mas o
   ponto exato falta);
2. **Existe registro/damper de renovação de ar acionável?** Se sim, a atuação
   futura mais realista não é umidificador, e sim **relé no damper** — hoje o
   `umidadeMeta` é registrado mas não atua em nada;
3. **Escolha final da umidade:** RS485 (recomendado) ou SHT31 + extensor — o
   autor pediu as duas registradas; a decisão de compra fica para o momento.

## 8. O que este documento não cobre

- Dimensões da estufa, número de estaleiros e capacidade em grades;
- Práticas específicas de outras regiões produtoras.
