# Supressão de incêndio (acionamento automático) — estudo

Ideia do autor (jul/2026): acoplar ao aparelho um sistema que **apaga o incêndio
automaticamente**, com caixa d'água de **350–500 L**. O aparelho já **detecta**
fogo (sensor de luz / temperatura); a ideia é ele também **atuar**.

> **Ressalva de segurança e escopo.** O assistente **não é engenheiro de proteção
> contra incêndio**. Para o galpão do autor / protótipo, isto é orientação
> técnica geral. **Como produto vendido, supressão de incêndio entra em normas
> (NBR 10897, Corpo de Bombeiros), responsabilidade civil e ART de profissional
> habilitado** — não deve ser comercializado sem um engenheiro responsável.
> Além do TCC; material de trabalho futuro.

---

## 1. Realidade da caixa de 350–500 L

A vazão que combate fogo **esvazia 350–500 L em ~1 a 5 minutos**. Logo, este é um
sistema de **ataque inicial / ganhar tempo** — abafa o começo e dá minutos de
resposta. **Não** é um sistema de incêndio completo. Dimensionar expectativa por
isso.

## 2. Cano — por zona de temperatura

Erro clássico: PVC comum. **PVC amolece a ~60 °C**, e o galpão passa de 74 °C no
ar — deforma já na cura normal e **derrete no fogo**, na hora que mais importa.

| Zona | Cano | Porquê |
|---|---|---|
| **Dentro do galpão** (quente + exposto ao fogo) | **Aço** (galvanizado/preto) | cano de sprinkler real; aguenta calor e chama |
| Alternativa mais barata dentro | **CPVC** (~90 °C) | usado em sprinkler residencial; mas o calor da cura come a margem |
| **Fora** (tanque → galpão, frio) | PVC comum | barato, ambiente ameno |
| ❌ Dentro | PVC comum | amolece a 60 °C, derrete no fogo — **não usar** |

## 3. Bicos — a armadilha da temperatura

**Bico fusível comum abre a 68–72 °C. A cura chega a 74 °C** → dispararia
**durante a estufada normal**, encharcando e **perdendo o fumo**. Dois caminhos:

1. **Bico fusível de ALTA temperatura** (≥93 °C, classe intermediária/alta): só
   abre em fogo real, não na cura. Passivo, cada bico decide sozinho, sem
   eletrônica;
2. **Dilúvio: bicos abertos + válvula solenoide (NF) + acionamento pelo ESP.** O
   aparelho detecta incêndio → abre a solenoide + liga a bomba → todos os bicos
   jorram. **É o que casa com o projeto** ("acionamento automático pelo
   aparelho"). Bico aberto de latão/inox, leque cheio.

**Recomendado:** dilúvio pelo ESP (é a proposta do autor), com fusível de alta
como **backup passivo** opcional.

## 4. Bomba — submersa × externa

| | Submersa (no tanque) | Externa (fora) |
|---|---|---|
| Escorva | **sempre escorvada** (boa p/ ficar meses parada) | pode perder escorva — precisa **válvula de pé** |
| Manutenção | tirar do tanque | fácil, vê funcionando |
| Pressão | modelos baratos têm pouca — escolher de pressão | fácil achar alta pressão |

**O que decide não é submersa × externa**, e sim resolver três coisas:

- **Pressão suficiente** para os bicos cobrirem a área;
- **Proteção contra funcionamento a seco:** quando os 350–500 L acabam, a bomba
  **queima** se seguir ligada — precisa de sensor de nível / desliga automático;
- **Energia durante o incêndio** (ver §5) — o ponto crítico.

## 5. O ponto crítico: energia na hora do fogo

O fogo (ou a falta de luz) pode **cortar a energia** — e a bomba elétrica morre
**exatamente quando é necessária**. Um sistema de incêndio que depende da rede
falha no pior momento. Soluções, em ordem de robustez:

1. **Tanque elevado + gravidade** (sem bomba): a água desce sozinha, **imune a
   queda de energia** — o cenário-título do projeto. Pressão baixa (≈1 bar por
   10 m de altura) limita alcance, mas **funciona quando tudo mais falhou**.
   Exige estrutura para elevar;
2. **Bomba 12 V + bateria** (mesma lógica do resto do projeto): funciona na queda,
   dá pressão. Precisa manter a bateria carregada e testada;
3. ❌ Bomba só na rede: falha se o fogo/queda cortar a luz. Evitar como única via.

## 6. Itens obrigatórios (qualquer configuração)

- **Acionamento manual de backup** — não confiar só na eletrônica;
- **Proteção contra funcionamento a seco** na bomba;
- **Teste antes de cada safra** — sistema parado ~8 meses precisa ser validado
  antes de valer (encaixa no checklist sazonal, ver `VIABILIDADE_COMERCIAL.md`
  §7.12);
- **Água × eletricidade:** o galpão tem motores e o próprio aparelho — pensar no
  risco de jogar água perto de instalação elétrica energizada.

## 7. Como conecta ao aparelho

O ESP já tem a borda de detecção de incêndio (`riscoIncendioAgora()`,
`perigoChama`). Atuar seria: nessa borda, acionar um **relé → solenoide + bomba**.
Cuidados de firmware: **confirmar** o incêndio (evitar disparo por leitura
espúria — descarga d'água é destrutiva e cara), e **acionamento manual** paralelo.
Ligar isto ao limiar de incêndio (hoje 175 °F, apertado — ver
`AMBIENTE_ESTUFA.md` §3) reforça a necessidade de rever esse limiar antes.

## 8. Em aberto / decisões do autor

- Elevar o tanque (gravidade) **ou** bomba com bateria? — decide a robustez na
  queda de energia;
- Dilúvio (bicos abertos, pelo ESP) **ou** fusível de alta, **ou** os dois;
- Cano de aço **ou** CPVC na zona quente;
- Vazão × cobertura desejada × os 350–500 L (dimensionar nº de bicos);
- **Se virar produto:** engenheiro de incêndio + normas + ART. Inegociável.
