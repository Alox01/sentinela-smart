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

O firmware trata **> 175 °F como risco de incêndio**
(`riscoIncendioAgora()`), e esse alerta é **não silenciável** e dispara push
com som de alarme.

Com a máxima de trabalho em 165 °F, sobram **apenas 10 °F** de folga — e o
sensor de temperatura fica **no ar mais quente da estufa**, logo na saída, antes
de perder calor para o fumo. Risco real de **alarme falso na secagem do talo**,
de madrugada, sem o produtor poder silenciar.

**Pendente decidir:** subir o limiar, ou trocá-lo por **velocidade de subida**
(fogo esquenta rápido, fornalha não), que separa melhor as duas situações.

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

### Umidade: depende do comprimento do cabo

| Distância | Opção |
|---|---|
| Até ~5 m | **SHT31** — faixa até 125 °C, 0–100 % UR, e **aquecedor interno** que evapora condensação |
| 10 m ou mais | **Sonda industrial RS485/Modbus** — feita para distância e ambiente agressivo; custa mais e dá mais trabalho no firmware |

I2C (do SHT31) **não tolera cabo longo**: poucos metros funcionam, dez ou mais
vira loteria.

### Uma folga a favor da durabilidade **[inferência]**

Na cura flue-cured os dois extremos **não coincidem**: a amarelação é muito
úmida mas relativamente fria; a secagem do talo é muito quente mas seca. O
sensor de umidade **nunca enfrenta 74 °C com 100 % de UR ao mesmo tempo** — o
que amplia bastante a vida útil.

---

## 7. Em aberto

Aguardando medição e observação do autor em campo:

1. **Metragem real dos cabos** até cada sensor — é o que decide entre SHT31 e
   RS485;
2. **Onde a caixa do aparelho será montada** (parede da cabine, quadro afastado);
3. **Que sensores os aparelhos comerciais da região usam** — o autor vai
   fotografar as ponteiras. Vale observar também:
   - se o cabo é **blindado ou par trançado** (indica que a distância exigiu
     cuidado com ruído, e informa sobre a viabilidade do I2C);
   - o **formato da ponteira** (sonda metálica sugere PT100 ou família DS18B20);
4. **Existe registro/damper de renovação de ar acionável?** Se sim, a atuação
   futura mais realista não é umidificador, e sim **relé no damper** — hoje o
   `umidadeMeta` é registrado mas não atua em nada.

## 8. O que este documento não cobre

- Dimensões da estufa, número de estaleiros e capacidade em grades;
- Práticas específicas de outras regiões produtoras;
- Se o controle local usa **bulbo seco e bulbo úmido** (padrão clássico do
  flue-cured) ou umidade relativa direta — o sistema atual usa UR direta, que é
  outra grandeza.
