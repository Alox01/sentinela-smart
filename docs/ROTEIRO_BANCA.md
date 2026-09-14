# Roteiro de estudo para a banca

Para chegar na apresentação (23/11 a 04/12/2026) dominando o que está no artigo.
A ideia não é decorar: é conseguir explicar **com as suas palavras** cada coisa
que o texto afirma. Se uma frase do artigo você não souber explicar, ela é a
primeira a estudar — ou a sair do texto.

**Escopo, para responder sem hesitar:** o TCC é a **camada de software — o
aplicativo e a nuvem**. O controlador (aparelho e firmware) é o **projeto
complementar**. Para testar o app com hardware de verdade, foi montado um
protótipo do controlador em placa.

---

## 1. O sistema em um minuto

> Estufa de fumo precisa de controle de temperatura o tempo todo, e no campo a
> internet cai. Um sistema que depende só da nuvem para quando mais precisa. A
> plataforma resolve isso com uma arquitetura **híbrida**: o controlador na
> estufa decide sozinho (é a **borda**, *edge*), o aplicativo fala com ele
> **direto pela rede local** sempre que dá, e a **nuvem** entra como
> complemento — histórico, acesso de longe e aviso no celular. Se a internet
> cai, nada para: o controlador segue alarmando, o app segue lendo pela rede
> local, e o que foi pedido sem conexão fica numa fila e é entregue quando ela
> volta.

Se a banca só lembrar de uma frase: **a nuvem ajuda, mas não é necessária para a
estufa funcionar.**

---

## 2. As três partes e como conversam

```
  CONTROLADOR (projeto complementar)        APLICATIVO (Flutter)
  ESP32 + sensores + sirene   <── rede local (HTTP) ──>  lê a cada 3 s, manda comando
        │                                                 │
        │ internet: manda leitura (1/min e na hora do     │ internet: quando não acha
        │ alarme), busca comando (a cada 20 s)            │ o controlador na rede local
        ▼                                                 ▼
                       NUVEM (Node.js + Express no Render)
                 PostgreSQL (Supabase) · push (Firebase) · vigia
```

| Parte | Tecnologia | O que faz |
|---|---|---|
| Aplicativo | Flutter / Dart, banco local Isar | mostra, comanda, guarda histórico local e a **fila** de comandos offline, gera relatório PDF/CSV |
| API | Node.js + Express, hospedada no Render | recebe leituras, grava histórico, guarda comandos para o controlador buscar, envia push, vigia silêncio |
| Banco | PostgreSQL gerenciado (Supabase) | histórico das estufadas |
| Push | Firebase Cloud Messaging | notificação com o app fechado |
| Controlador | ESP32 (projeto complementar) | lê sensores, decide o alarme **localmente**, atende o app pela rede local |

**Por que HTTP e não MQTT?** Simplicidade e custo: o controlador já precisa de
um servidor HTTP para o app na rede local, e a mesma linguagem serve para a
nuvem. MQTT exigiria um *broker* sempre ligado, um serviço a mais para manter.

---

## 3. Os cinco fluxos que a banca vai perguntar

### 3.1 Leitura ao vivo — como o app escolhe o caminho

1. O app tenta primeiro o **controlador na rede local** (pelo IP ou pelo nome
   `sentinela-xxxx.local`), com prazo curto (3 s).
2. Se não responde, tenta a **nuvem** (prazo maior, 15 s, porque o servidor
   gratuito pode estar "acordando").
3. Sem nenhum dos dois: **OFFLINE**, mostrando os últimos valores.
4. O selo **LOCAL / NUVEM / OFFLINE** fica sempre visível na tela.

**Isso é a Computação de Borda na prática:** a decisão (alarme) e o dado ficam
perto da estufa; a nuvem é um caminho a mais, não o único.

### 3.2 Comando — com e sem internet (fila + última escrita vence)

- **Com conexão local:** o app manda direto ao controlador, que aplica na hora
  ("Comando aplicado").
- **Pela nuvem:** o app manda para a API, que guarda; o controlador **busca** a
  cada 20 s (ele fica atrás do roteador da propriedade, ninguém de fora
  consegue "chamar" ele — quem procura é ele). O app mostra "Aguardando a estufa
  aplicar".
- **Sem conexão nenhuma:** o comando vai para a **fila** no banco local do app
  (Isar). Na tela: "OFFLINE | 1". Quando a conexão volta, a fila é enviada.

**Última escrita vence (Last Write Wins), por campo:** cada ajuste (temperatura,
umidade, silêncio) carrega o **momento** em que foi feito. Na reconexão, o
controlador só aceita o que for **mais novo** que o que ele tem. Exemplo para a
banca: *"se o produtor pediu 70 no app sem internet às 11:02, mas às 11:05
mudou para 65 nos botões do aparelho, quando a fila chega o 70 é descartado —
ele é mais velho que o 65."*

**Por que por campo e não o registro inteiro?** Para uma mudança de temperatura
feita no app não apagar uma mudança de umidade feita no aparelho no mesmo
período.

### 3.3 Histórico e relatório

- A nuvem grava **uma leitura a cada 10 min** durante a estufada, e **na hora**
  quando o alarme muda, o ajuste muda ou aparece um desvio relevante. Assim o
  banco não enche (plano gratuito: 500 MB) e os momentos importantes ficam.
- O relatório **junta** o histórico da nuvem com o que o app gravou no celular.
- **PDF:** resumo, eventos, gráfico e uma tabela com **uma leitura por hora**
  (legível). **CSV:** **todas** as leituras.
- Os eventos de "ajuste alterado" e de alarme saem **das leituras** — por isso
  aparecem mesmo o que foi feito nos botões do aparelho e o alarme que tocou com
  o app fechado.

### 3.4 Alertas

- **Com o app fechado**, quem avisa é a **nuvem**, pelo Firebase: temperatura
  fora da faixa, incêndio, e **"sem receber dados do aparelho"** — um vigia no
  servidor percebe quando o controlador fica em silêncio (uns 5 min) e avisa; e
  avisa de novo quando ele volta.
- **Desvio = mais de 8 °F do ajuste**, para cima ou para baixo — a **mesma**
  regra no controlador, no servidor e em todas as telas. 8 exato ainda é normal;
  9 já é desvio.
- **Umidade nunca toca alarme** (na secagem, ficar abaixo é o objetivo); ela é
  registrada e desenhada no gráfico.
- **Sirene e aviso são canais diferentes:** desligar a sirene no aparelho não
  desliga o aviso no celular nem apaga o alarme do relatório.

### 3.5 Segurança — quem pode comandar a estufa

- Cada controlador tem a **sua chave**. O app só consegue a chave estando **na
  frente do aparelho**: segurando os 3 botões (modo de configuração) e digitando
  o **PIN que aparece no visor**. Ou seja, parear exige **presença física**.
- Comandar (mudar ajuste, silenciar) exige a chave **daquele** aparelho. A chave
  de um não abre outro.
- O dono pode **revogar** o acesso de um celular.

---

## 4. Testes automatizados

### O que é, em uma frase

> Um teste automatizado é um pequeno programa que usa o código do sistema com
> uma situação conhecida e **confere se o resultado é o esperado**. Se alguém
> mudar o código e quebrar aquilo, o teste falha na hora.

Cada correção feita depois de um teste em campo ganhou um teste que **reproduz o
erro** — assim o erro não volta sem ninguém perceber. É por isso que o número
cresceu.

### Como rodar na frente da banca (uns 20 segundos cada)

```bash
cd estufa_server
npm test
```
Termina com `# pass 230` e `# fail 0`.

```bash
cd estufa_app
flutter test
```
Termina com `All tests passed!` (196).

### Os três testes para dominar

**Teste 1 — "8 ainda é normal, 9 já é desvio"**
Arquivo: `estufa_app/test/detector_oscilacao_test.dart`

```dart
test('9 abaixo do ajuste ja e desvio', () {
  final d = DetectorOscilacao();
  d.avaliarTemperatura(leitura: 81, ajuste: 90, nowMs: 0);
  final ev = d.avaliarTemperatura(leitura: 81, ajuste: 90, nowMs: 10 * min);
  expect(ev?.tipo, 'oscilacao_temperatura');
  expect(ev!.descricao, contains('mais de 8°F'));
});
```
Como explicar: *"Crio o detector, digo que a leitura é 81 com ajuste 90 — 9
abaixo. A primeira chamada só marca o começo; depois de 10 minutos na mesma
situação, ele tem que gerar o evento de desvio. Um teste irmão faz o mesmo com
98 e 82 — 8 de diferença — e confere que **não** gera nada. É a fronteira da
regra, testada dos dois lados."*

**Teste 2 — o erro do relatório vazio**
Arquivo: `estufa_app/test/historico_nuvem_test.dart`

Como explicar: *"Num teste de campo de 36 horas, o relatório mostrou uma noite
inteira sem leitura, mas o banco tinha tudo. A causa: com o celular no Wi-Fi da
estufa, o app pedia o histórico ao **controlador**, que não guarda histórico, e
recebia 'não encontrado'. Este teste simula exatamente isso — um controlador
falso que responde 404 e uma nuvem falsa que responde com uma leitura — e
confere que o app vai **direto na nuvem** e recebe a leitura. Rodei o teste no
código antigo: falhava. No corrigido: passa."*

Esse é o melhor exemplo de **teste que nasce de um erro real**.

**Teste 3 — a rajada de ajustes vira uma linha**
Arquivo: `estufa_app/test/eventos_de_ajuste_test.dart`

```dart
final leituras = [
  leitura(0, ajusteTemp: 70),
  leitura(1, ajusteTemp: 75),
  leitura(2, ajusteTemp: 80),
  leitura(3, ajusteTemp: 85),
  leitura(4, ajusteTemp: 80),
  leitura(20, ajusteTemp: 80),
];
expect(descricoes(leituras), ['Ajuste de temperatura alterado de 70 para 80°F.']);
```
Como explicar: *"O produtor mexe no ajuste várias vezes em poucos minutos. O
relatório não pode virar uma lista de 70, 75, 80, 85… Mudanças a menos de 5
minutos uma da outra viram uma linha só: de onde saiu (70) para onde parou
(80)."*

---

## 5. Perguntas prováveis — e como responder

**"O que acontece se a internet cair no meio da secagem?"**
O controlador continua lendo e alarmando sozinho. O app, se estiver na rede da
propriedade, continua lendo direto dele. Comandos feitos sem conexão ficam na
fila e são entregues na volta. Foi testado desligando o roteador.

**"E se faltar luz?"**
O controlador desliga. A nuvem percebe o silêncio e avisa "sem receber dados do
aparelho"; quando volta, avisa de novo. Distinguir falta de luz de falta de
internet exige hardware (bateria e sensor de tensão) — fica para o projeto
complementar.

**"E se o app e o aparelho mudarem o ajuste ao mesmo tempo?"**
Vence o mais recente, pelo carimbo de tempo — por campo (seção 3.2).

**"Por que Fahrenheit?"**
É a escala usada no manejo da cura do fumo, e dá passos mais finos de ajuste.

**"Qualquer um pode comandar a estufa pela internet?"**
Não. Precisa da chave daquele aparelho, e ela só é obtida na frente dele, com o
PIN do visor (seção 3.5).

**"Por que o comando pela nuvem demora?"**
O controlador fica atrás do roteador e não pode ser chamado de fora; ele
**busca** os comandos a cada 20 s. O app avisa que está aguardando.

**"Quanto custa manter?"**
Nos testes, zero: planos gratuitos do Render, do Supabase e do Firebase. O
servidor gratuito hiberna sem uso; um ping a cada 10 min o mantém acordado.

**"E o banco de dados enche?"**
Por isso a política de gravação: uma leitura a cada 10 min e as mudanças
importantes na hora — em vez de gravar tudo.

**"Funciona no iPhone?"**
O código é multiplataforma (Flutter), mas a versão iOS não foi validada, por
falta de aparelho Apple. Está declarado como limitação.

**"Onde foi testado?"**
Em casa, com o controlador em bancada — não numa estufa em plena safra. As
temperaturas foram as do ambiente. Está nas limitações.

**"Por que um simulador?"**
Para desenvolver o app antes do controlador estar pronto. Ele segue o mesmo
"contrato" (as mesmas mensagens) do controlador real — por isso a troca não
mudou a arquitetura.

**"O que você faria diferente / o que vem depois?"**
Mandar a fila de comandos direto ao controlador quando ele está na rede local;
validar iOS; política de limpeza do banco; e, com o projeto complementar, o
controlador guardar leituras sem internet para enviar depois.

**"Quem fez o aparelho?"**
O controlador é o projeto complementar. Para testar o app com hardware real, foi
montado um protótipo em placa.

---

## 6. Limitações — como falar delas

Falar **antes** de perguntarem passa segurança. Três frases bastam:

1. *"A validação foi em bancada, não em estufa em safra."*
2. *"Comando pela nuvem leva até uns 20 segundos; o app mostra que está
   aguardando."*
3. *"Sem internet no controlador, a nuvem fica sem leituras daquele período;
   o app só cobre se estiver aberto na rede da propriedade."*

---

## 7. Números para lembrar

| O quê | Número |
|---|---|
| Desvio | mais de **8 °F** (8 é normal, 9 é desvio) |
| Incêndio por temperatura | acima de **175 °F** |
| App lê o controlador | a cada **3 s** |
| Controlador manda leitura à nuvem | a cada **1 min** (e na hora do alarme) |
| Controlador busca comando na nuvem | a cada **20 s** |
| Nuvem grava no histórico | a cada **10 min** + mudanças na hora |
| Aviso de "sem dados" | depois de uns **5 min** de silêncio |
| Estufada da validação | **39 h 39 min**, **265** leituras, **4** alarmes |
| Teste offline | comando aplicado às **11:03:47** de 14/09 |
| Testes automatizados | **230** no servidor, **196** no app |

---

## 8. No dia

- Roteiro da demonstração ao vivo: `docs/DEMO.md`.
- Chegar cedo e **testar tudo no celular da apresentação**: selo LOCAL ou
  NUVEM, um ajuste, um relatório.
- Abrir a URL do servidor ~1 min antes, para ele acordar.
- Ter os prints e as fotos dos testes à mão, caso a rede do local falhe — o
  Wi-Fi da faculdade não serve para o controlador (página de login); usar o
  **roteador do celular**.
