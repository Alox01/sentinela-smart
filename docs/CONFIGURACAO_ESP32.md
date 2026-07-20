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

## Modo de configuracao — **nao implementado** (trabalho futuro)

> **Status:** planejado, nao feito. Hoje `WIFI_SSID` e `WIFI_PASS` sao
> constantes no `.ino`: trocar de roteador, mudar a senha ou levar o aparelho
> para outra propriedade **exige regravar o firmware**, com computador e cabo.

Essa e a limitacao mais visivel do projeto para quem usa, e vale reconhece-la no
TCC: um sistema que argumenta autonomia em ambiente rural nao deveria depender
de um tecnico a cada troca de roteador.

O que **hoje** reduz o problema (e por isso ela nao bloqueia o uso):

- **mDNS** (`sentinela-XXXXXX.local`, ja implementado) mantem o aparelho
  encontravel mesmo quando o DHCP muda o IP — que e a causa mais comum de
  "sumiu do app" depois de uma queda de energia;
- **reserva de DHCP no roteador** resolve o endereco de forma definitiva quando
  ha acesso a ele;
- a chave de acesso e configurada **pelo app**, por estufa, e nao exige tocar no
  firmware.

Ou seja: o que muda com frequencia (IP) ja esta coberto; o que exige regravar
(SSID/senha) muda raramente. O custo de implementar o modo AP e moderado — a
metade dificil ja existe, porque o NVS e o `WebServer` estao no firmware — mas
consome espaco de flash (o binario ja ocupa 84%) e nao fazia parte dos
objetivos da proposta.

Fluxo planejado, para quem retomar:

1. Ao segurar um botao fisico durante a inicializacao, o ESP32 entra em modo de
   configuracao.
2. O ESP32 cria uma rede Wi-Fi propria, por exemplo `Sentinela-Config`.
3. O produtor ou tecnico conecta o celular nessa rede.
4. O navegador abre uma pagina local, por exemplo `http://192.168.4.1`.
5. A pagina permite configurar:
   - Wi-Fi da propriedade;
   - senha do Wi-Fi;
   - modo de IP: DHCP ou fixo;
   - IP fixo, gateway e mascara, quando necessario;
   - chave de acesso do aparelho;
   - nome do aparelho.
6. O ESP32 salva as configuracoes em memoria persistente.
7. O ESP32 reinicia e volta ao modo normal.

No ESP32, essas configuracoes podem ser salvas com `Preferences` ou NVS.

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

- Implementar o modo de configuracao por AP (`Sentinela-Config`) e a pagina em
  `192.168.4.1`.
- Salvar **Wi-Fi, IP e nome** em memoria persistente — o NVS ja e usado para os
  ajustes de temperatura/umidade, entao o mecanismo esta pronto; falta so
  gravar tambem as credenciais.
- Adicionar a combinacao de botoes para entrar no modo de configuracao.
- Testar DHCP reservado e IP fixo em campo.

Concluidas:

- ~~Alinhar endpoints finais entre app, simulador e ESP32~~ — feito, contrato
  unico em `CONTRATO_API.md`.
- ~~mDNS no firmware~~ — feito (v1.2.0).
- ~~Persistir a configuracao para nao resetar no boot~~ — feito (v1.6.0, NVS).
- ~~Validar reconexao depois de queda de energia~~ — o firmware reconecta
  sozinho; falta apenas repetir a medicao com a versao atual.
