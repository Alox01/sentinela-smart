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
- **Sensor de luz = alarme de maior prioridade (papel de chama):** quando o
  sensor de luz dispara, o buzzer toca continuo e **nao pode ser silenciado** —
  mesmo comportamento do alerta de incendio no `logica.js`. Ressalva: um LDR
  comum e um detector de fogo fraco; para incendio de verdade, avaliar um sensor
  de chama dedicado (IR).
- **Alarme de temperatura (silenciavel):** buzzer intermitente quando a
  temperatura sai de `alvo +/- margem`; o botao do buzzer silencia so este.
- **Botoes:** vermelho = entra em modo ajuste e incrementa o alvo (+1);
  verde = decrementa o alvo (-1) no ajuste, ou mostra a umidade por 10 s fora
  dele; botao do buzzer = silencia o alarme de temperatura.
- **LEDs:** alerta geral (luz ou temperatura); controle de temperatura com
  histerese (liga <= alvo-2, desliga >= alvo+2 — indica aquecedor, sem rele);
  umidade acende so enquanto o visor mostra a umidade.
- **Sem atuacao real:** LEDs + buzzer apenas; sem reles para aquecedor/ventilador
  (coerente com "hardware e projeto complementar").

### Estado da integracao (concluida)

> Esta secao descrevia uma lacuna que **nao existe mais**. O firmware
> (v1.8.0) fala o contrato completo do app: rotas `/status`, `/dados`,
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

### 2. IP fixo alto no ESP32

Essa e a alternativa quando nao houver acesso ao roteador.

O ESP32 pode permitir configurar manualmente um IP alto dentro da rede local,
por exemplo `192.168.1.220`.

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

O Monitor Serial mostra o nome completo ao iniciar. Ele pode ser cadastrado no
campo IP ou endereço do app, sem `http://` e sem porta. Assim, uma mudança do
IP entregue pelo DHCP não exige editar a estufa cadastrada.

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
   vermelho). O visor mostra `ConF`.
2. O aparelho cria a rede Wi-Fi **`Sentinela-Config`**.
3. Conecte o celular nela. O aparelho responde **qualquer consulta de nome com
   o proprio IP**, entao o celular costuma abrir a pagina sozinho ("conectar-se
   a rede"), como num Wi-Fi de hotel. Se nao abrir, digite
   **`http://192.168.4.1`** no navegador.

   > O Android normalmente avisa que a rede **nao tem internet** e pergunta se
   > quer continuar conectado — e preciso aceitar, senao ele volta para os dados
   > moveis e a pagina nao carrega.
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

### Nao implementado

Configurar **IP fixo, gateway e mascara** pela pagina. O DHCP com o mDNS ja
cobre o caso real (o aparelho continua encontravel quando o IP muda), e os
campos extras custariam espaco de flash sem resolver problema observado.

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

- **Testar o modo de configuracao em campo** (compila e a logica esta escrita,
  mas so vale depois de abrir a pagina num celular de verdade).
- Testar DHCP reservado em campo.
- Avaliar *flash encryption* se a senha em claro na NVS virar preocupacao real.

Concluidas:

- ~~Alinhar endpoints finais entre app, simulador e ESP32~~ — feito, contrato
  unico em `CONTRATO_API.md`.
- ~~mDNS no firmware~~ — feito (v1.2.0).
- ~~Persistir a configuracao para nao resetar no boot~~ — feito (v1.6.0, NVS).
- ~~Implementar o modo de configuracao por AP e a combinacao de botoes~~ —
  feito (v1.9.0).
- ~~Salvar Wi-Fi e chave em memoria persistente~~ — feito (v1.9.0).
- ~~Validar reconexao depois de queda de energia~~ — o firmware reconecta
  sozinho; falta apenas repetir a medicao com a versao atual.
