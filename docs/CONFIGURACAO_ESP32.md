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

### Lacuna de integracao (importante)

O firmware atual e **autonomo e offline**: nao tem Wi-Fi, servidor HTTP, JSON,
token nem persistencia de configuracao (o alvo volta a 76 F a cada boot). Ou
seja, ele **ainda nao fala com o app/nuvem**. Toda a camada de conectividade que
o app espera — rotas `/status`, `/dados`, `/sincronizar`, `/leitura`, o contrato
JSON e o cabecalho `X-Device-Token` — precisa ser adicionada a este firmware
para a integracao acontecer. O app foi validado contra o simulador, que ja fala
esse contrato; este e o principal trabalho quando o aparelho chegar.

Pontos a alinhar entre firmware e servidor/app:

- alvo padrao (firmware 76 F x app 90 F na nova estufada);
- margem/tolerancia (firmware +/- 8 F x servidor +/- 5 F);
- deteccao de incendio (firmware: sensor de luz binario x servidor:
  temperatura > 175 F ou sensor de chama);
- persistir a configuracao no ESP32 (NVS/Preferences) para nao resetar no boot.

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

Como facilitador, o ESP32 pode anunciar um nome local, por exemplo:

```text
sentinela.local
```

Assim o app poderia tentar conectar por nome em vez de depender apenas do IP.

Observacao importante: em alguns celulares Android e roteadores, mDNS pode nao
funcionar de forma consistente. Por isso, ele deve ser um facilitador, nao a
unica forma de conexao.

## Modo de configuracao

O ESP32 deve ter um modo de configuracao para recuperar ou alterar dados sem
reenviar firmware.

Fluxo sugerido:

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

- Implementar modo de configuracao no firmware do ESP32.
- Salvar Wi-Fi, IP, nome e chave em memoria persistente.
- Adicionar botao fisico ou combinacao de botoes para entrar no modo de
  configuracao.
- Testar DHCP reservado, IP fixo e mDNS.
- Validar reconexao depois de queda de energia.
- Alinhar endpoints finais entre app, simulador e ESP32.
