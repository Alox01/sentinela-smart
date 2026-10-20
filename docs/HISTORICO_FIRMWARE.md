# Histórico do firmware

Este registro morava no topo de `sentinela_esp32.ino`, com uma entrada por
versão. Eram 94 linhas antes da primeira linha de código, lidas por quem abria o
arquivo para achar uma função — e o `git log` já conta o *quando*. Saiu de lá e
veio para cá.

O que ele guarda e o código não guarda é o **motivo medido em campo**: por que a
janela de acomodação é de 5 minutos e não 20, por que o limite de incêndio segue
o ajuste, por que a chave nunca é trocada sozinha. Cada uma dessas foi uma
estufa real se comportando diferente do esperado. Apagar isso obrigaria a
redescobrir na próxima estufada.

## A numeração reiniciou

Em **04/08/2026** o firmware voltou para **1.0**, por decisão do produtor. Tudo
o que está listado abaixo é numeração de bancada — 25 versões contando cada
experimento, que ninguém além de nós viu rodar. A numeração de agora é a do
produto e começa quando o aparelho está pronto para ser usado de verdade.

Uma consequência prática: **o número não sobe sozinho a cada mudança de
comportamento.** Ele passou a significar *o que está na mão de alguém*, e não *o
que mudou no código* — que o `git log` já conta. Quem mexer no firmware **não
incrementa** `VERSAO_FIRMWARE`; o produtor avisa quando muda.

Por isso este arquivo para aqui. O que vier depois de 1.0 é histórico de
produto, e as entradas abaixo continuam valendo pelo **motivo**, não pelo
número: cada uma foi uma estufa real se comportando diferente do esperado.

## Depois do 1.0, por motivo

### 20/10/2026 — tranca de estado entre os dois núcleos, e memória visível

Saiu de uma revisão do arquivo inteiro. Nenhuma das três muda comportamento:
duas fecham corridas que ninguém tinha visto acontecer, e a terceira só publica
números que já existiam dentro do chip.

**A corrida que importava.** `aplicarAjustes()` tem dois chamadores em núcleos
diferentes: `buscarComandosNuvem()` no núcleo 0 e `handleSincronizar()` no
núcleo 1. Ela faz lê-compara-escreve nos carimbos de tempo, que são `long long`
— **dois armazenamentos de 32 bits** nesta máquina. Dois comandos no mesmo
instante podiam deixar metade de um carimbo atualizada.

Perder um ajuste seria o dano pequeno. O grande é o carimbo ficar com a metade
alta absurda: a partir dali **todo comando é ignorado para sempre**, em
silêncio, até alguém reiniciar o aparelho — e nada no visor nem no diário diria
por quê. Probabilidade baixa, diagnóstico quase impossível em campo.

Entrou `trancaEstado`, um mutex só, com duas regras escritas no código: quem o
segura pode pedir a tranca do diário, nunca o contrário; e **nada de I/O com
ele na mão**. Por isso as funções de rede passaram a *fotografar* as chaves e
soltar antes do HTTPS, em vez de ler as `String` compartilhadas no meio de uma
chamada que leva segundos.

**A segunda corrida** era a mesma coisa nas `String` `tokenAparelho` e
`chaveAnterior`, lidas no núcleo 0 e escritas no núcleo 1 por
`handleConfigSalvar()`. Estava protegida só pela circunstância de aquela rota
exigir o PIN do visor — proteção por sorte, não por desenho.

**E o que não dava para medir.** O arquivo usa `String` em tudo, e isso
fragmenta o heap ao longo de semanas. Não havia uma única medida de memória no
aparelho: um reinício no décimo dia de estufada não tinha como ser atribuído a
nada. O `/dados` passou a publicar `heapLivre`, `heapMinimo` e
`pilhaNuvemLivre`. O que vale olhar é o **mínimo**, que guarda o fundo do poço
mesmo quando a medida do momento está folgada.

Um detalhe que quase virou erro: no port Xtensa o `uxTaskGetStackHighWaterMark()`
devolve **bytes**, porque o `StackType_t` ali é `uint8_t`. No FreeRTOS de manual
a conta sai em palavras e se multiplica por 4 — fazer isso aqui reportaria
quatro vezes mais folga do que existe. Conferido no cabeçalho do core instalado.

### 20/10/2026 — a trava do botão se solta sozinha em 5 minutos

Pedido do produtor. A trava do botão do buzzer existe para parar **só a
ventoinha** enquanto se põe lenha ou se mexe na fornalha, sem desligar o
aparelho. O que faltava era o caminho de volta: travada e esquecida, ela ficava
travada até alguém reparar — e o único aviso são os dois pontos piscando no
visor, que ninguém vê de longe nem de noite.

O custo do esquecimento é alto e silencioso: a ventoinha não gira, a estufa
esfria, a fase atrasa e a estufada se perde. O custo de soltar sozinha é
pequeno, porque **soltar não liga nada** — devolve o comando ao ajuste, que
decide pela temperatura. Com a estufa quente, ela segue parada.

`TEMPO_MAXIMO_TRAVA_VENTOINHA_MS = 5 min`, contado de
`ventoinhaBloqueadaDesdeMs`, carimbado no toque do botão. A verificação é a
primeira coisa dentro de `aplicarVentoinha()`, para a decisão da ventoinha já
começar enxergando o estado novo em vez de um laço atrasada.

**O comando na mão continua inteiro.** Apertar o botão antes dos 5 minutos
destrava na hora, como sempre fez, e reinicia o prazo se travar de novo. Nada
do que existia mudou de comportamento — só foi acrescentado um fim.

O `/dados` passou a publicar `segundosAteDestravar`, para o aplicativo poder
mostrar quanto falta em vez de só dizer que está travada.

**Cinco minutos cobrem a tarefa com folga, e isso é dado de campo:** pôr lenha
no forno não chega perto desse tempo (produtor, 20/10/2026). Quando o prazo
vence, o serviço acabou há muito — então a ventoinha não parte com ninguém de
mãos na fornalha, que era o risco que se cogitou ao escrever isto.

Se um dia a tarefa mudar, ou a trava passar a servir para outra coisa, o número
está numa constante só.

### 16/10/2026 — teto de 165 °F no ajuste e trava de segurança na saída

Pedido do produtor, e são **duas** regras, de naturezas diferentes.

A primeira é um **teto no que se pode pedir**: `ALVO_MAXIMO_F = 165`. Vale em
`definirTemperaturaAlvo()`, que é por onde passa tudo — os botões do aparelho,
o comando vindo da nuvem e o que a sincronização traz de volta. Barrar só no
botão deixaria a porta da nuvem aberta.

A segunda é um **teto no que se pode suportar**:
`TEMPERATURA_LIMITE_VENTOINHA_F = 165`, verificado em `aplicarVentoinha()`,
na última linha antes do pino. Acima disso a ventoinha não liga e, se estiver
girando, para na hora — sem consultar a histerese, o prazo mínimo entre
partidas nem a trava do botão.

O motivo da segunda é o que a torna diferente de tudo o mais no arquivo: ela
**não confia no resto do código**. A decisão normal de ligar vem de
`ledControleLigado`, calculado em `atualizarEstadoTemperatura()`. Se um defeito
qualquer deixar essa variável ligada com a estufa a 170 °F, a ventoinha
continuaria soprando ar na fornalha — que é exatamente o que transforma
temperatura alta em incêndio. A trava lê a temperatura e decide sozinha.

`limiteFogoF()` **não** foi mexido, e isso foi deliberado numa segunda olhada.
Com o teto em 165 °F o ramo que soma 5 ao ajuste virou inalcançável, e chegou a
ser simplificado para o valor fixo. Foi revertido: a regra vive em três
linguagens — firmware, `logica.js` e `limiar_incendio.dart` — e já divergiu em
campo. O teto é decisão de produto e pode mudar; a regra do limite é do domínio.
Apagar em um e não nos outros dois recriaria exatamente a divergência de julho.

**Pendência conhecida:** o aplicativo ainda deixa o seletor ir até 200 °F. Um
pedido acima de 165 é aceito pela tela, cortado pelo aparelho e devolvido como
165 — funciona, mas confunde. Alinhar o app ao firmware continua a fazer.

## O que foi numerado em bancada

### 1.26.0

Entrar no modo de configuracao deixou de ser sorte. Tres coisas conspiravam: a
leitura dos tres botoes era crua, sem debounce (unico lugar do firmware assim),
entao um chacoalho de contato zerava a contagem inteira; nao havia retorno
nenhum antes dos 3 s, entao a contagem podia ter reiniciado sem ninguem saber; e
`verificarModoConfig()` rodava DEPOIS das chamadas a nuvem, que seguram o loop
por 1-2 s num handshake HTTPS - apertar bem nessa hora significava ser notado
so 2 s depois, com a contagem comecando dali. Agora ha tolerancia de 150 ms para
solturas, os tres LEDs ficam acesos enquanto conta (o apito continua sendo so a
confirmacao de que entrou), a leitura vem antes da nuvem e a nuvem espera
enquanto os tres botoes estao na mao.

### 1.25.0

`semsenha=1` no POST /salvar grava senha vazia DE PROPOSITO. Vazio sozinho sempre quis dizer "mantenha a atual", e por isso nao havia como dizer "esta rede nao tem senha": o aparelho guardava a senha antiga, tentava entrar com ela numa rede aberta e nao conectava, sem nada explicando. Ausente = comportamento de antes.

### 1.24.0

PIN de 4 digitos no visor para entregar a chave. O ponto de acesso do modo de configuracao e ABERTO: sem o PIN, quem estivesse ao alcance do wifi naquele momento pediria /config/identidade e levaria a chave sem nunca chegar perto do aparelho. Sorteado a cada entrada, morre depois de 5 erros, e o visor de 4 digitos o mostra inteiro.

### 1.23.0

Reporta o proprio `ipLocal` em cada leitura. O nome mDNS era a unica porta local do app; quando ele nao resolve, o endereco guardado vira a segunda. Tambem permite dizer de fora onde o aparelho esta, em vez de mandar procurar no roteador.

### 1.22.0

Chave vazia no formulario MANTEM a atual, em vez de apagar. Apagar fazia o boot seguinte gerar uma chave aleatoria desconhecida do app e da nuvem, e o aparelho ficava mudo sem nada explicando. O formulario ja prometia isso; era a gravacao que nao cumpria.

### 1.21.0

Guarda o gateway e a mascara que o ROTEADOR entrega no DHCP e usa esses valores quando um IP fixo e configurado sem eles. O produtor nao tem por que saber esses numeros, e adivinhar .1 quebrava redes com o gateway em .254 - local funcionando e nuvem muda, sem nada explicando. Os campos sairam do app; o formulario do aparelho ainda os aceita. O gateway aprendido tambem vai em /config/identidade, para o app deixar o campo de IP fixo quase pronto com a faixa certa.

### 1.20.0

O app le a identidade (id, nome local e CHAVE) de `GET /config/identidade`, que so responde no modo de configuracao - presenca fisica. O formulario HTML deixa de vir com a chave preenchida. Assim o produtor nunca precisa ver nem digitar a chave; sem exibir, a recuperacao passa a ser entrar no modo de configuracao de novo, que e o modelo do adesivo do roteador.

### 1.19.0

Reporta `alertaTemperatura` - a CONDICAO de temperatura fora da faixa - separada de `alarmeAtivo`, que diz se a sirene esta tocando. Desligar a sirene do aparelho zerava `alarmeAtivo`, e a nuvem deixava de mandar a notificacao de temperatura para o celular: a sirene da estufa estava mandando no aviso do celular, que tem preferencias proprias.

### 1.18.0

Chave de acesso POR APARELHO. Gera uma aleatoria quando nao existe nenhuma (aparelho novo), registra na nuvem por TOFU e oferece "gerar nova chave" no modo de configuracao - presenca fisica -, rotacionando na nuvem com prova de posse da anterior. Aparelho que ja tem chave nunca e trocado sozinho: se o registro falhasse, o produtor perderia o acesso ao que funcionava.

### 1.17.0

O limite de incendio por temperatura passa a acompanhar o ajuste (ajuste > 170 F -> ajuste + 5), como logica.js ja fazia no servidor. Os dois discordavam: com ajuste em 172, o aparelho alarmava aos 175 e a nuvem so aos 177.

### 1.16.0

O silencio cobre so o fogo que JA existia quando o botao foi apertado. Fogo que comeca durante os 10 min cancela o silencio e toca: apertar diz "ja sei DESTE fogo", nao "nao me avise de fogo por 10 min". As duas causas contam separado, e uma que cessa e volta conta como nova. Achado em teste de campo - silenciar e poucos minutos depois acender a chama no sensor nao produzia som nenhum.

### 1.15.0

A temperatura de incendio (>175 F) passa a tocar CONTINUO, como a chama. Ate aqui ela caia no bipe intermitente do alarme comum, apesar de ser tao grave - quem esta na estufa distingue os dois pelo som.

### 1.14.0

O silencio de 10 min passa a valer tambem para FOGO. Quem aperta o botao (ou o do app) ja esta ciente - viu o aviso ou ouviu a sirene - e foi buscar agua ou chamar socorro; a sirene ao lado so atrapalha. Nao e liga/desliga: o prazo vence sozinho e o alarme volta, entao nao da para silenciar e esquecer.

### 1.13.0

Segurar SO o botao do buzzer por 3 s liga/desliga a sirene de temperatura deste aparelho, sem celular nem internet. O interruptor do app e global (vale para todas as estufas); desligar uma so e uma decisao tomada na frente dela. Confirma com apitos e LED.

### 1.12.0

O alarme de TEMPERATURA pode ser desligado pelo app (buzzerAtivo, LWW, NVS). Fogo nunca e afetado: sensor de chama e temperatura de incendio (limiteFogoF()) tocam sempre. So a sirene fisica cala - o push segue.

### 1.11.0

Ao entrar no modo de configuracao, apita e pisca os 3 LEDs (sinal fisico inconfundivel); visor mostra "----" em vez de tentar "ConF", que um display de 7 segmentos nao escreve legivel.

### 1.10.0

A pagina de configuracao mostra o nome local do aparelho (antes so aparecia no Monitor Serial, que exige um computador com a IDE) e aceita IP fixo, para roteador do provedor onde nao da para reservar.

### 1.9.0

Modo de configuracao por ponto de acesso (segurar os 3 botoes por 3 s) - Wi-Fi e chave passam a sair da NVS, entao trocar de roteador nao exige mais regravar o firmware com um computador.

### 1.8.0

Teto da folga da acomodacao de 20 para 8 F/% - o teto antigo cabia um desvio grande demais dentro do "perdao" de um ajuste.

### 1.7.0

Janela de acomodacao de 20 para 5 min - medido na estufa real, que alcanca o alvo novo antes disso; a janela antiga atrasava o alerta.

### 1.6.0

Ajustes guardados na memoria nao-volatil - uma queda de energia nao devolve mais o alvo ao padrao no meio de uma estufada.

### 1.5.0

A folga da acomodacao cobre so a distancia que a mudanca criou - aproximar o alvo da temperatura atual nao silencia mais o alarme.

### 1.4.0

Acomodacao no proprio aparelho apos mudar o alvo - antes o ESP alarmava na hora ao subir o ajuste, ignorando a acomodacao que so existia no app.

### 1.3.0

Envio imediato quando o alarme/incendio comeca ou termina (antes a nuvem so sabia no ciclo de 1 min, e um teste rapido nem chegava).

### 1.2.0

Nome local mDNS exclusivo por aparelho, com fallback para o IP.

### 1.1.0

Silencio com prazo de 10 min, busca de comandos na nuvem, leituras inteiras, id unico por chip.
