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
