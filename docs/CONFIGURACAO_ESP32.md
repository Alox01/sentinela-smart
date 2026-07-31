# Configuracao do ESP32

Este documento guarda a estrategia planejada para configurar o aparelho fisico
sem precisar reenviar o codigo para o ESP32 toda vez que mudar Wi-Fi, IP ou
chave de acesso.

## Objetivo

O produtor precisa conseguir conectar o app ao aparelho mesmo em ambiente rural,
onde pode haver queda de energia, troca de roteador, internet instavel ou falta
de acesso administrativo ao roteador.

A ideia e ter mais de uma forma de encontrar e recuperar o aparelho.

## Mapa de pinos (montagem de referencia)

Pinagem de uma montagem de referencia do ESP32 (prototipo de monitoramento,
indicacao e alarme). Serve de base para o firmware quando o aparelho chegar.

| Componente | Sinal | GPIO | Observacao |
|---|---|---|---|
| DHT22 / AM2302 (temp + umidade) | DATA | 32 | pull-up de 4,7 kOhm entre DATA e 3V3; le em Celsius, converter para Fahrenheit no firmware |
| Sensor de luz | D0 | 35 | GPIO35 e entrada-apenas (sem pull-up interno); ver nota do sensor de chama abaixo |
| Display TM1637 (4 digitos) | CLK / DIO | 18 / 19 | 4 digitos: mostra temperatura e serve para o PIN de emparelhamento (ver `SEGURANCA_COMANDOS.md`) |
| Botao do buzzer | — | 13 | INPUT_PULLUP, botao para GND — silenciar alarme |
| Botao verde | — | 4 | INPUT_PULLUP, botao para GND |
| Botao vermelho | — | 33 | INPUT_PULLUP, botao para GND |
| LED vermelho (alerta geral) | — | 26 | resistor de 220 Ohm |
| LED verde (umidade) | — | 27 | resistor de 220 Ohm |
| LED de temperatura | — | 14 | resistor de 220 Ohm |
| Buzzer (sirene fisica) | + | 25 | negativo no GND |

Comportamento do firmware atual (montagem de referencia):

- **Fahrenheit:** ja resolvido — o firmware le com `dht.readTemperature(true)`,
  que retorna Fahrenheit direto da biblioteca. Nao precisa converter.
- **Fogo = alarme de maior prioridade:** as duas causas - sensor de luz (papel
  de chama) e temperatura de incendio (>175 F) - tocam o buzzer **continuo**
  desde a v1.15.0. O alarme comum de temperatura toca **intermitente**, e e por
  esse contraste que quem esta na estufa distingue "va ver a lenha" de "corra"
  sem olhar o celular.
  Desde a v1.14.0 o fogo aceita o **silencio de 10 min**, como os demais - quem
  aperta ja esta ciente e foi agir -, mas **nao pode ser desligado**: o hold de
  3 s no botao do buzzer segue recusado para fogo, porque desligar nao tem prazo
  para voltar. E, desde a v1.16.0, o silencio cobre **so o fogo que ja existia**
  quando o botao foi apertado: fogo novo dentro dos 10 min cancela o silencio e
  toca. Apertar diz "ja sei DESTE fogo", nao "nao me avise de fogo por 10 min".
  Ressalva: um LDR comum e um detector de fogo fraco; para incendio de verdade,
  avaliar um sensor de chama dedicado (IR).
- **Alarme de temperatura (silenciavel):** buzzer intermitente quando a
  temperatura sai de `alvo +/- margem`; o botao do buzzer silencia so este.
- **Botoes:** vermelho = entra em modo ajuste e incrementa o ajuste (+1);
  verde = decrementa o ajuste (-1), ou mostra a umidade por 10 s fora dele;
  botao do buzzer = silencia qualquer alarme por 10 min (segurando 3 s, liga ou
  desliga a sirene de temperatura deste aparelho).
- **LEDs:** alerta geral (luz ou temperatura); controle de temperatura com
  histerese (liga <= alvo-2, desliga >= alvo+2 — indica aquecedor, sem rele);
  umidade acende so enquanto o visor mostra a umidade.
- **Sem atuacao real:** LEDs + buzzer apenas; sem reles para aquecedor/ventilador
  (coerente com "hardware e projeto complementar").

### Estado da integracao (concluida)

> Esta secao descrevia uma lacuna que **nao existe mais**. O firmware
> (desde a v1.8.0) fala o contrato completo do app: rotas `/status`, `/dados`,
> `/sincronizar`, o JSON de `CONTRATO_API.md`, o cabecalho `X-Device-Token`,
> o push de leituras para a nuvem e a busca de comandos remotos. A
> configuracao **persiste em NVS/`Preferences`** — o alvo nao volta mais ao
> padrao a cada boot. Validado em hardware real.

Diferencas que permanecem entre o aparelho e o simulador, de proposito ou por
decidir — vale citar no TCC em vez de fingir que nao existem:

| Ponto | Aparelho | Simulador/servidor |
|---|---|---|
| Margem do alarme de temperatura | +/- 8 F | +/- 5 F |
| Alvo inicial (antes do 1o ajuste) | 76 F | 90 F na nova estufada |
| Deteccao de incendio | sensor de luz + temp > 175 F | temp > 175 F ou sensor de chama |

A margem diferente e a divergencia mais relevante: o aparelho tolera mais antes
de tocar a sirene do que o simulador. Como o app passou a **espelhar o estado
que o aparelho reporta** (em vez de recalcular por conta propria), isso nao
gera mais contradicao na tela — mas o simulador continua sendo um pouco mais
sensivel que o equipamento real.

O alvo inicial so aparece antes do primeiro ajuste: depois disso o valor vem do
NVS, inclusive apos queda de energia.

## Estrategia de rede

### 1. DHCP com reserva no roteador

Essa e a melhor opcao quando houver acesso ao roteador.

O tecnico ou produtor reserva um IP para o MAC do ESP32. Assim, sempre que o
ESP32 reiniciar, o roteador entrega o mesmo endereco para ele.

Exemplo:

```text
ESP32 MAC: AA:BB:CC:DD:EE:FF
IP reservado: 192.168.1.220
```

Vantagens:

- evita conflito com outros aparelhos;
- funciona bem quando ha queda de energia;
- nao exige alterar o codigo do ESP32;
- facilita cadastrar o endereco no app uma unica vez.

### 2. IP fixo alto no ESP32 — **implementado** (firmware 1.10.0)

Essa e a alternativa quando nao houver acesso ao roteador — o caso comum quando
o roteador e do provedor e so ele tem a senha de administrador. Sem isso,
restaria reconferir o IP a cada queda de energia.

Configuravel na pagina do aparelho e na tela do app, em "Endereco fixo
(opcional)". Vazio = DHCP.

**Gateway e mascara sairam do app na v1.21.0.** Sao numeros que o produtor nao
tem por que saber, e o aparelho ja sabe: ele guarda o que o roteador entrega em
cada conexao por DHCP e usa isso quando um IP fixo e configurado sem eles. A
ordem e: o que foi informado > o que o roteador ensinou > o palpite (`.1` da
faixa e `255.255.255.0`).

Isso importa porque adivinhar `.1` quebra rede com o gateway em `.254`: o
aparelho fica com a rede local funcionando e a nuvem muda, sem nada na tela
explicando. Como o IP fixo e uma reserva usada **depois** de o aparelho ja ter
entrado na rede, o valor aprendido quase sempre existe. O formulario HTML do
aparelho ainda aceita os dois, para o caso raro de precisar forcar.

O gateway tambem e usado como DNS, porque o aparelho precisa resolver nomes para
falar com a nuvem.

**Um IP invalido e recusado antes de gravar**, e um que falhe ao ser aplicado
cai no DHCP: um endereco errado deixaria o aparelho invisivel na rede, que e
pior do que um endereco que muda.

Essa opcao reduz a chance de conflito, mas nao elimina totalmente o risco. Se
outro aparelho receber o mesmo IP, pode haver falha de conexao.

Regras recomendadas:

- usar um IP no final da faixa da rede, como `.200` a `.250`;
- manter gateway e mascara iguais aos da rede local;
- se a conexao falhar, voltar para DHCP ou entrar no modo de configuracao.

### 3. Nome local por mDNS

O firmware anuncia automaticamente um nome local exclusivo, formado pelos seis
últimos caracteres do MAC do ESP32. Exemplo:

```text
sentinela-a1b2c3.local
```

**Onde ver o nome** (o produtor não tem a IDE do Arduino):

1. **Na tela "Configurar aparelho" do app** — em destaque, com botão de copiar;
2. **Na página servida pelo aparelho**, no topo do formulário e de novo na
   confirmação, porque o ponto de acesso some no reinício;
3. No Monitor Serial ao iniciar, para quem estiver com um computador.

Cadastre-o no campo de endereço da estufa, sem `http://` e sem porta. Assim, uma
mudança do IP entregue pelo DHCP não exige editar a estufa cadastrada.

Observação importante: em alguns celulares Android e roteadores, mDNS pode não
funcionar de forma consistente. Por isso, ele é um facilitador, não a única
forma de conexão: o IP exibido no Monitor Serial continua sendo a alternativa.
O mDNS funciona apenas na mesma rede local e não fornece acesso pela internet.

## Modo de configuracao — **implementado** (firmware 1.9.0)

Trocar de roteador, mudar a senha ou levar o aparelho para outra propriedade
**nao exige mais regravar o firmware**. As constantes `WIFI_SSID`, `WIFI_PASS` e
`DEVICE_TOKEN` no `.ino` passaram a ser apenas o **valor de fabrica**: o que
estiver gravado na NVS tem precedencia.

### Como usar

> **Caminho recomendado:** app → menu da estufa → **Configurar aparelho**. O
> formulario e o mesmo, sem digitar endereco nenhum. Os passos abaixo (rede e
> navegador) continuam valendo para quem nao tem o app instalado.

1. **Segure os tres botoes ao mesmo tempo por 3 segundos** (buzzer, verde e
   vermelho). O aparelho **apita e pisca os tres LEDs** ao entrar; o visor passa
   a mostrar `----`.
2. O aparelho cria a rede Wi-Fi **`Sentinela-Config`**.
3. Conecte o celular nela. O aparelho responde **qualquer consulta de nome com
   o proprio IP**, entao o celular costuma abrir a pagina sozinho ("conectar-se
   a rede"), como num Wi-Fi de hotel. Se nao abrir, digite
   **`http://192.168.4.1`** no navegador.

   > O Android normalmente avisa que a rede **nao tem internet** e pergunta se
   > quer continuar conectado — e preciso aceitar.
4. Preencha rede, senha e chave de acesso. **Senha em branco mantem a atual** —
   util para trocar so a chave.
5. Salvar reinicia o aparelho, que ja sobe na rede nova.

### Decisoes de projeto

- **Por que tres botoes, e nao um PIN no visor.** Segurar tres botoes ja e prova
  de presenca fisica, que era o que o PIN buscava garantir. Um PIN adicionaria
  atrito sem mudar quem consegue abrir o modo: em ambos os casos, so quem esta
  na frente do aparelho.
- **O que sobra de risco.** Enquanto o modo esta aberto, a rede fica sem senha e
  qualquer um no alcance pode abrir a pagina. Duas coisas limitam isso: o modo
  so abre por acao fisica deliberada, e **se fecha sozinho apos 5 minutos** sem
  uso, reiniciando. Um modo aberto por engano nao fica exposto indefinidamente.
- **O alarme continua funcionando durante a configuracao.** Sensor, sirene, LEDs
  e visor seguem ativos; so a rede muda. Uma estufa nao pode ficar sem vigilancia
  porque alguem foi mexer no Wi-Fi.
- **Nenhum botao age sozinho durante a combinacao.** Sem isso, apertar os tres
  silenciaria o alarme e mexeria no alvo no caminho — os contatos nunca fecham
  ao mesmo tempo. Ao entrar no modo, os ajustes sao recarregados da NVS para
  descartar qualquer toque acidental.
- **A nuvem e ignorada no modo de configuracao.** Como ponto de acesso o
  aparelho nao tem saida para a internet; tentar falar com a nuvem so gastaria
  segundos do loop em conexoes fadadas a falhar.
- **A senha do Wi-Fi nao volta preenchida** no formulario: deixa-la no HTML
  entregaria a senha da propriedade a quem estivesse na rede aberta.
- **Portal cativo, em tres partes.** Ninguem decora `192.168.4.1`, entao o
  objetivo e o celular abrir a pagina sozinho. Isso exige as tres:
  1. **DNS coringa** — o aparelho responde qualquer consulta de nome com o
     proprio IP. Sem isto a falha acontece antes de chegar nele;
  2. **DNS anunciado no DHCP** — alguns Android consultam o servidor que ja
     tinham e nunca chegam ao coringa;
  3. **Desvio (HTTP 302)** na verificacao de internet — e esse sinal que o
     sistema entende como "ha uma pagina para abrir". Servir a pagina direto,
     com codigo 200, nao aciona o aviso de forma confiavel.
- **Ainda assim e melhor esforco.** O comportamento varia por fabricante e
  versao. O bloqueador mais comum e o **DNS privado** do Android (Rede → DNS
  privado): ativo, o celular resolve nomes por fora e nunca percebe o portal.
  **Por isso a tela no app existe:** ela nao depende de nada disso — o app fala
  direto com `192.168.4.1`, sem navegador e sem o produtor digitar endereco.
  O formulario servido pelo aparelho continua como saida para quem nao tem o
  app instalado.
- **Custo:** ~12 KB de flash (84% → 85%).

### Limitacao conhecida

A senha do Wi-Fi e a chave de acesso ficam na NVS **sem criptografia**. Quem
tiver o aparelho em maos e souber ler a memoria consegue extrai-las. E o padrao
nesse tipo de dispositivo, mas nao deve ficar implicito. Mitigar exigiria
*flash encryption* do ESP32, que complica a gravacao e a manutencao.

### IP fixo pela pagina — implementado (v1.10.0)

Esta secao dizia "nao implementado" ate 24/07/2026, quando a v1.10.0 acrescentou
os campos de **IP fixo, gateway e mascara**. A decisao mudou por um caso real: em
roteador de provedor o produtor as vezes **nao consegue reservar DHCP**, e ai o
mDNS sozinho nao basta.

Os campos sao opcionais — em branco, o aparelho segue no DHCP. Preenchendo so o
IP, o firmware assume o `.1` da mesma faixa como gateway e `255.255.255.0` como
mascara, que e o arranjo da esmagadora maioria das redes domesticas.

## Chave de acesso

A chave de acesso protege comandos que alteram o aparelho, como ajuste de
temperatura, ajuste de umidade e silenciamento de alarme.

Regras planejadas:

- leituras podem continuar liberadas na rede local;
- comandos devem exigir a chave;
- a chave nao deve ser enviada na URL;
- o app deve enviar a chave em cabecalho HTTP, como `X-Device-Token`;
- cada aparelho pode ter uma chave propria.

Exemplo de cabecalho:

```http
X-Device-Token: minha-chave-da-estufa
```

Se o produtor esquecer a chave, o caminho de recuperacao deve ser o modo de
configuracao fisico do ESP32. Isso evita depender de abrir o codigo e reenviar o
firmware.

## Provisionamento planejado: nome e chave gerados pelo aparelho **[planejado]**

Desenho (jul/2026) para a **primeira configuracao**: em vez de o produtor
inventar e digitar a chave em varios lugares, o **aparelho gera a chave, mostra**
e ela se propaga sozinha. Ainda **nao implementado** — planejamento e trade-offs.

### Como o aparelho sabe que e a primeira vez

Nao precisa detectar nada: **no boot, se a NVS nao tem chave, gera uma; se ja
tem, mantem.** Primeiro boot de fabrica = NVS vazia → gera; dali em diante,
persiste. "Gera-se-nao-existe", sem evento especial de "primeira configuracao".

### Nome x chave: naturezas diferentes

| | Muda? | Por que |
|---|---|---|
| **Nome** (`sentinela-xxxxxx`) | **nunca** — ja vem do MAC do chip | e endereco, nao segredo (como o endereco da casa) |
| **Chave de acesso** | permanente por padrao, **mas regeravel sob demanda** | e segredo; venda ou vazamento exige revogar |

O **nome ja e permanente e unico de graca** (vem do MAC): nao precisa ser
"gerado", so **mostrado**. Isso simplifica a Parte 1.

### Parte 1 — nome mDNS ate o cadastro (barata, independente)

Metade ja existe: a tela de configuracao **le e mostra** o nome. Falta emendar:

- Na tela de sucesso, um botao **"Cadastrar esta estufa"** abre o formulario de
  nova estufa **ja preenchido** com o nome (e a chave);
- Cuidado da troca de rede: o aparelho reinicia na rede da casa, entao o celular
  precisa **voltar ao Wi-Fi de sempre** antes do nome resolver. A tela avisa.

### Parte 2 — **implementada** em 29/07/2026 (v1.18.0 + servidor)

O que ficou de pé, e as decisões que o desenho abaixo previa mas não fechava:

- **O aparelho gera a própria chave** (32 hex, `esp_random()`) **só quando não
  existe nenhuma** — aparelho novo, ou com a constante do topo ainda no valor de
  fábrica. Aparelho que já tem chave **nunca** é trocado sozinho: se o registro
  na nuvem falhasse (nuvem hibernada, internet fora), a chave nova valeria só no
  aparelho e o produtor perderia o acesso ao que funcionava.
- **Trocar é sempre ato deliberado:** "gerar uma chave nova" no modo de
  configuração (presença física). A chave nova aparece na tela seguinte — é a
  última vez que ela é mostrada.
- **Registro na nuvem por TOFU**, mas **atrás da autenticação**, e essa foi a
  decisão de segurança do dia. TOFU puro (rota aberta, primeiro a registrar
  vence) deixaria qualquer um reivindicar um `idHardware` antes do aparelho — e o
  id **não é segredo**, aparece em toda resposta de `/status`. Exigir a
  credencial atual mantém a âncora onde já estava (quem tem a chave global é o
  produtor) e não abre exposição nova. O aparelho consegue registrar porque a
  chave dele ainda **é** a global.
- **Rotação com prova de posse da anterior.** O aparelho guarda a chave
  substituída em NVS até a nuvem aceitar a troca, e só então a apaga. Sem isso,
  gerar chave nova trancaria o próprio aparelho fora da nuvem, porque a rotação
  exige a chave que ela tem.
- **A chave de um aparelho não comanda outro.** O middleware resolve a chave com
  o `idHardware` que a própria requisição menciona. Sem essa amarração, "chave
  por aparelho" não separaria nada: qualquer chave registrada abriria qualquer
  estufa. É o teste mais importante de `test/chave_aparelho.test.js`.
- **O app tambem leva a chave** (caminho B, feito na sequência): ao cadastrar ou
  editar uma estufa que já tem `idHardware` e chave, o app sobe
  `(idHardware, chave)` para a nuvem. A chave chega até ele pelo modo de
  configuração — presença física —, que a Parte 1 já devolvia ao formulário.
  Melhor esforço de propósito: falhar aí não pode derrubar o cadastro, que é o
  que o produtor está fazendo. E os dois caminhos (aparelho e app) caem no mesmo
  TOFU, então o primeiro que chegar resolve. Um **409** na subida é sinal útil: a
  nuvem guarda outra chave para aquele aparelho, ou seja, a do app está velha e
  os comandos remotos vão ser recusados até ela ser relida no modo de
  configuração.
- **A chave global continua valendo, de propósito.** Tirar antes de todos os
  aparelhos em campo registrarem a sua deixaria o produtor sem acesso remoto.
  Desligar é um passo separado, depois de provado em campo.

### Parte 3 — o produtor nunca vê a chave (v1.20.0)

Fluxo desenhado pelo produtor, com as correções que a revisão trouxe:

1. `+` no app **ou** segurar os 3 botões — em qualquer ordem;
2. no app, "primeira configuração": nome e senha do Wi-Fi da casa;
3. o app lê do aparelho `GET /config/identidade` — id, nome mDNS e **chave**;
4. o app mostra só o nome de conexão. A chave fica em memória e **nunca é
   exibida**;
5. salva → o aparelho reinicia na rede de casa;
6. o celular volta ao Wi-Fi de sempre;
7. **"Conferir se o aparelho responde"** antes de finalizar;
8. cadastra a estufa com o que já está em memória.

O que a revisão corrigiu na proposta:

- **O id não é criado, já existe** (vem do MAC). O id é o nome e não é segredo —
  aparece em toda resposta de `/status`. A chave é o segredo.
- **Nada de área de transferência.** Outros apps leem o clipboard e o Android
  ainda anuncia a colagem. O app já carregava a chave em memória, o que é
  estritamente melhor.
- **Uso único foi descartado.** Se o app fechasse ou o celular caísse da rede do
  aparelho no meio, a chave se perderia. A âncora certa não é "uma vez" e sim
  **enquanto no modo de configuração**, que já exige os 3 botões e expira
  sozinho: mesma proteção, sem a fragilidade.
- **O passo 7 não existia na proposta** e é o que impede terminar com uma estufa
  apontada para um endereço que nunca responde — o mDNS falha em parte dos
  celulares e roteadores, e o erro apareceria muito depois, parecendo outra coisa.

Consequência aceita: **não existe "esqueci minha chave"**. Sem exibir, a
recuperação é entrar no modo de configuração de novo — o modelo do adesivo do
roteador. O formulário HTML do aparelho deixou de vir com a chave preenchida;
quem usa o navegador direto ainda a vê ao gerar uma nova, que é o caminho de
recuperação sem o app.

Compatibilidade: firmware anterior a 1.20.0 não serve a rota, e aí o campo da
chave continua aparecendo no app — aparelho antigo não fica sem caminho.

**Para desligar a chave global (29/07/2026), o que foi verificado.** Todas as
rotas que o app chama na nuvem carregam `idHardware` — `/sincronizar` (quando
conhecido), `/agendamentos` (recusa sem ele), `/push/dispositivos` (obrigatório)
e `/status?idHardware=`. Ou seja, o app não precisa da chave global para uma
estufa que já tem id. Falta:

- **o simulador** (`ESP32_REALISTIC_V2`) registrar uma chave. Hoje ele é lido com
  a global. Basta editar a estufa dele no app com uma chave nova — a Fase 3 a
  sobe. Nada dentro do servidor precisa dessa chave: o simulador não autentica
  para fora, só é lido;
- **aparelho novo** entrar já com a chave registrada (pelo próprio aparelho na
  1.18.0, ou pelo app).

E o que **deixa de funcionar de propósito**: as rotas de teste sem `idHardware`
(`POST /push/verificar-silencio`) e qualquer `curl` de diagnóstico com a chave
global. Nenhuma delas é caminho de produção.

Desenho original abaixo, mantido porque o raciocínio segue valendo.

#### Desenho original

**Geracao e exibicao.** O aparelho gera uma chave aleatoria quando a NVS nao tem
uma (ver acima). O "ovo e galinha" — como o app le a chave se e ela que protege
o aparelho? — resolve-se por **presenca fisica: so no modo de configuracao** (3
botoes) o aparelho **revela a chave**, sem autenticacao, porque quem segura os
botoes esta na frente dele. Mesmo principio do **adesivo do roteador**. Em
operacao normal a chave **nunca** aparece (`/status` so diz "tem chave: sim/nao").

**Perder a chave = reentrar no modo de configuracao.** Segura os 3 botoes → o
aparelho **mostra a chave atual** de novo. Basta recadastrar no app.

**Venda / troca de dono / vazamento = "gerar nova chave".** Aqui esta o ponto
critico: se a chave fosse **so** permanente, o **dono antigo continuaria sabendo
ela** depois de vender — e, com remoto configurado, poderia mexer na estufa do
novo dono. Entao o modo de configuracao tem a opcao **"gerar nova chave"**: quem
compra entra no config, gera uma nova, e o dono antigo fica **trancado para
fora**. A chave e permanente **por conveniencia** (nao se perde), nao por
obrigacao.

**Rotacao com a nuvem.** Quando a chave e regerada, a nuvem (que guardava a
antiga por TOFU) precisa aceitar a nova. Jeito limpo: **o proprio aparelho faz a
troca** — no instante da regeracao ele conhece a chave **velha e a nova**, entao
avisa a nuvem "sou o aparelho X, prova com a chave antiga, atualize para a nova".
A nuvem aceita porque a velha bate, e a antiga morre. O app nao precisa
autenticar a rotacao; o aparelho faz.

**Subir para o Render — a parte dificil.** Hoje o servidor usa **uma chave
global** (`ESTUFA_API_TOKEN`); chave por aparelho exige guardar `idHardware →
chave` e validar por aparelho (o grosso do trabalho, e **codigo de seguranca**).
Como a chave chega la:

| Caminho | Como | Trade-off |
|---|---|---|
| **A) Aparelho registra** | No 1o push manda a propria chave; nuvem guarda (1o a registrar vence — **TOFU**) | Simples, sem conta. Risco: pre-registrar um `idHardware` — baixo (id vem do MAC, nao adivinhavel) |
| **B) App e o carteiro** | App le a chave no modo config (presenca fisica) e sobe `(idHardware, chave)` | O ato fisico do produtor e a ancora de confianca; ainda precisa do TOFU na nuvem |
| **C) Chave de fabrica** | Segredo de provisionamento no firmware autoriza o registro | Mais forte, mas o segredo fica no firmware (extraivel) |

**Recomendado: A + B.** Aparelho gera, mostra no modo config, app le e guarda **e**
sobe para a nuvem com **TOFU** (1o registro vence; seguintes tem que bater com a
chave existente). Mata a friccao de digitar a chave 3x e, de brinde, e **mais
seguro** que chave escolhida pelo produtor (aleatoria, unica por aparelho).

### Ressalvas honestas

- **Sem conta de usuario** no projeto, o modelo e "quem tem a chave, comanda". A
  **presenca fisica** (3 botoes) e a unica ancora forte. Aceitavel nesta escala,
  mas deve constar como limitacao;
- **Presenca fisica = poder total.** Quem alcanca os 3 botoes ve a chave e pode
  gerar outra. Numa estufa isso e razoavel (o aparelho fica na propriedade), mas
  significa que **nao ha protecao contra quem tem acesso fisico** — inclusive
  para revogar o dono legitimo. Aceitavel aqui, mas e o preco de nao ter conta;
- **A revogacao depende de acao fisica no aparelho.** Se o produtor vende e
  **esquece** de gerar chave nova, o antigo dono mantem acesso. O fluxo de venda
  deveria **empurrar** a regeracao (ex.: um passo "novo dono? gere uma chave"),
  senao a protecao existe mas nao e usada;
- O maior risco esta no **servidor** (global → por aparelho): erro ali = aparelho
  comandavel por qualquer um. Fazer com calma, com teste;
- **Fasear:** Parte 1 rapida e independente; Parte 2 e um bloco a parte.

## Comunicacao com o app

No modo local atual, o app conversa com o aparelho por HTTP na mesma rede Wi-Fi.

Fluxo esperado:

```text
App -> HTTP GET -> ESP32
ESP32 -> JSON -> App

App -> HTTP POST com chave -> ESP32/servidor
ESP32/servidor -> resposta de comando -> App
```

O simulador deve manter rotas e JSON parecidos com o ESP32 para que os testes
locais continuem validos mesmo sem o aparelho fisico.

## O que explicar no TCC

Esta solucao combina com a proposta hibrida porque:

- funciona localmente sem internet, usando HTTP na mesma rede Wi-Fi;
- permite uso com simulador durante desenvolvimento;
- prepara o projeto para nuvem no futuro;
- evita depender de uma unica forma de descobrir o aparelho;
- reduz a necessidade de manutencao tecnica quando mudar Wi-Fi, IP ou chave.

## Tarefas futuras

Pendentes:

- **Provisionamento (ver secao acima):** Parte 1 — botao "Cadastrar esta estufa"
  levando o nome mDNS ao formulario; Parte 2 — chave gerada pelo aparelho,
  mostrada no modo config, propagada ao app e a nuvem (TOFU). A Parte 2 muda o
  servidor de chave global para chave por aparelho.
- **Testar o modo de configuracao em campo** (compila e a logica esta escrita,
  mas so vale depois de abrir a pagina num celular de verdade). Vale para o
  portal cativo e para os campos de IP fixo, nunca exercitados fora do codigo.
- Testar DHCP reservado em campo.
- **Gravar a v1.15.0 no aparelho** — a ultima versao provada em hardware e a
  1.9.0; da 1.10.0 em diante (IP fixo, confirmacao sonora do modo config, sirene
  desligavel, hold de 3 s no botao do buzzer) so ha compilacao.
- Avaliar *flash encryption* se a senha em claro na NVS virar preocupacao real.

Concluidas:

- ~~IP fixo, gateway e mascara pela pagina~~ — feito (v1.10.0). Estava marcado
  como "nao implementado" ate o caso do roteador de provedor sem reserva DHCP.

- ~~Alinhar endpoints finais entre app, simulador e ESP32~~ — feito, contrato
  unico em `CONTRATO_API.md`.
- ~~mDNS no firmware~~ — feito (v1.2.0).
- ~~Persistir a configuracao para nao resetar no boot~~ — feito (v1.6.0, NVS).
- ~~Implementar o modo de configuracao por AP e a combinacao de botoes~~ —
  feito (v1.9.0).
- ~~Salvar Wi-Fi e chave em memoria persistente~~ — feito (v1.9.0).
- ~~Validar reconexao depois de queda de energia~~ — o firmware reconecta
  sozinho; falta apenas repetir a medicao com a versao atual.
