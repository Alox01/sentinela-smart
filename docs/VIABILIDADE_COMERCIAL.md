# Viabilidade comercial: nuvem, custo e a promessa vitalícia

Discussão iniciada pelo autor em jul/2026, pensando na venda do aparelho + app em
escala (potencialmente milhares de unidades e produtores simultâneos).

> **Escopo:** isto está **além do TCC**. A arquitetura atual (Render + Supabase +
> FCM, planos grátis) é ótima para o trabalho e prova o conceito. Este documento
> é planejamento de **produto**, e daria uma boa seção de "trabalhos futuros /
> viabilidade comercial" no artigo.

**As seções são análise técnica (do assistente) sobre o problema colocado pelo
autor. Não são decisões tomadas** — o autor ainda vai trazer ideias próprias.

---

## 1. O problema, nas palavras do autor

- A venda pode chegar a **milhares de unidades** usando app e aparelho ao mesmo
  tempo;
- O produtor rural quer algo **vitalício** — comprou, é dele, não quer
  mensalidade;
- O autor **também não quer pagar assinatura para sempre** para manter o serviço;
- Os planos grátis de **Render, Supabase e Firebase** não aguentam essa escala.

**O medo é duplo e explícito:** (a) o custo mensal que sairia do bolso do autor,
e (b) a promessa de "vitalício" que ele precisa conseguir cumprir para vender.
Ambos pesam igual.

---

## 2. A verdade estrutural

**"Vitalício" e "serviço de nuvem sempre ligado" são incompatíveis por
natureza.** Um servidor 24h custa dinheiro todo mês, para sempre. Se o produtor
paga uma vez e usa por 10 anos, alguém banca 10 anos de servidor — o autor, ou o
serviço morre. Não existe nuvem grátis eterna; existe nuvem que *alguém* paga.

Logo, o erro seria prometer "nuvem vitalícia grátis". A saída **não** é achar um
plano grátis que aguente a escala — é mudar a arquitetura para que **o custo pare
de crescer com o número de aparelhos**.

---

## 3. O que já protege o projeto: edge-first

O sistema é **edge-first** — o aparelho é a fonte da verdade e **funciona sem
nuvem** na rede local. Isso permite separar o produto em duas camadas com
naturezas diferentes:

| Camada | Custo para o autor | Promessa honesta ao produtor |
|---|---|---|
| **Monitorar/controlar na propriedade** (aparelho + app no mesmo Wi-Fi) | **Zero** — nenhum servidor | **Vitalício de verdade** — funciona para sempre |
| **Acesso remoto + histórico + push** | Custo mensal real | Isso é um **serviço** |

O produto comprado é do produtor para sempre. O que roda pela internet é serviço.
E a maioria dos produtores está **na propriedade** quando a estufa cura — o
remoto é conveniência, não o essencial. Isso sustenta a promessa vitalícia sem
mentir.

---

## 4. O ponto técnico que decide o custo

Um **simulador só** já estourou os 500 MB do Supabase (ver
`PLANO_BANCO_DADOS.md`). Mil aparelhos a 1 leitura/min = **~1,4 milhão de linhas
por dia**. Qualquer plano grátis morre em dias; qualquer plano pago vira conta
que cresce sem parar.

**A raiz é usar a nuvem como banco de histórico.** O custo que escala com o
número de aparelhos é o **banco de dados**. Correção:

- **Tirar o histórico da nuvem.** Ele já pode viver onde não custa nada: no
  **aparelho** (fonte da verdade — precisaria de cartão SD) e no **celular** (o
  Isar já guarda por estufada — isso já existe);
- **A nuvem vira um relé burro:** valor atual, repasse de comando, gatilho de
  push. Quase sem armazenamento. Um relé que não guarda nada **não cresce** — o
  custo é o mesmo com 10 ou 10.000 aparelhos.

**Resultado: o custo descola do número de unidades.** Deixa de ser "quanto mais
vendo, mais pago" e vira um valor fixo pequeno. Este é o ponto central de tudo.

---

## 5. Boas notícias concretas

- **FCM (push) é grátis em qualquer escala.** O Firebase não cobra por mensagem
  nem por aparelho. A peça mais assustadora é a que escala de graça — **pode
  manter**;
- **O relé, sendo leve, é barato.** **MQTT** é feito para milhares de aparelhos
  pequenos com mensagens minúsculas; roda num **VPS de ~US$ 5/mês** aguentando
  **milhares** de conexões. Substituiria o Render, cujo modelo HTTP+polling é
  pesado e ainda dorme no grátis;
- **Render e Supabase grátis foram perfeitos para o TCC**, mas nenhum é feito
  para produção. Trocá-los é a graduação natural do projeto, não um fracasso.

---

## 6. Modelos para bancar o relé sem assinatura eterna do autor

Com a nuvem virando relé barato de custo fixo, três modelos ficam viáveis (dá
para combinar):

1. **Margem do hardware paga o relé.** Custo de nuvem por aparelho quase zero
   (relé + FCM, sem banco) → alguns reais no preço de venda cobrem anos de
   operação. Comunicado como "nuvem inclusa";
2. **Remoto como opcional pago.** Quem quer ver de longe assina barato; quem fica
   na propriedade usa tudo localmente de graça. Alinha quem gera custo com quem
   paga;
3. **Honestidade de prazo.** "Acesso remoto garantido por X anos" em vez de
   "vitalício" — mais verdadeiro, evita a promessa que quebra.

**A evitar:** escalar o modelo atual (banco na nuvem + servidor sempre ligado
guardando tudo) para produção. É o único que faz o autor pagar cada vez mais
conforme vende mais.

---

## 7. Em aberto

- **Ideias do próprio autor** — ele quer trazer as dele (esta conversa continua);
- Definir se o histórico local fica no **cartão SD do aparelho**, no **celular**,
  ou nos dois;
- Custo real de um VPS com broker MQTT na escala pretendida (estimar com números,
  não só ordem de grandeza);
- Como o acesso remoto atravessa o NAT da propriedade sem um servidor central
  caro (o relé MQTT resolve isso, mas precisa ser desenhado);
- Migração: como sair de Render/Supabase sem quebrar quem já usa.

## 8. Relação com o TCC

Não é necessário para o trabalho — a arquitetura atual prova o conceito. Mas
rende uma seção forte de **viabilidade comercial / trabalhos futuros**: mostra
que o projeto foi pensado além do protótipo, com consciência de custo e de
escala. Ver também `AMBIENTE_ESTUFA.md` (limitações de hardware) como material da
mesma natureza.
