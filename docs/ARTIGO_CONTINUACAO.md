# Texto para o artigo — para colar no Word

Reescrito em 14/09/2026, para a entrega de 16/09. Substitui o rascunho de
agosto, que tinha afirmações que deixaram de ser verdade (o controlador guardar
leituras sem internet, o push "não implementado", o hardware como futuro).

**Escopo, decidido pelo autor:** o TCC é a **camada de software — aplicativo e
nuvem**. O controlador físico (aparelho e firmware) é o **projeto
complementar**; aqui ele aparece só como a outra ponta da comunicação e como o
equipamento com que a validação foi feita.

**Como usar:** cada bloco diz onde entra no `.docx` e qual parágrafo substitui
(pelo começo dele). Ajustar numeração de seção, figuras e quadros ao template.

---

## 1. INTRODUÇÃO — trocar um trecho

No 4º parágrafo (começa com "Para isso, a arquitetura considerada neste
trabalho..."), trocar:

> ~~um dispositivo controlador externo, previsto para integração posterior,~~

por:

> um dispositivo controlador externo, desenvolvido em projeto complementar,

### 1b. Objetivos e estrutura (15/09/2026)

Pedido pelo modelo do professor (slide 11): objetivo geral, objetivos
específicos e, no fim, a estrutura do artigo. Cada objetivo específico tem um
resultado na seção 4 que responde a ele.

**Substituir o 3º parágrafo** ("Para solucionar esse problema, este trabalho
propõe..."):

> Para solucionar esse problema, este trabalho tem como objetivo geral
> desenvolver a camada de software de uma plataforma IoT híbrida — o aplicativo
> móvel e a API em nuvem — para o monitoramento e o controle de estufas de
> secagem de fumo, capaz de manter o acompanhamento da temperatura e da
> umidade, o histórico operacional e os alertas de segurança mesmo em
> propriedades rurais com conectividade instável. Para atingi-lo, foram
> definidos os seguintes objetivos específicos:
>
> a) definir uma arquitetura de software híbrida, que priorize a comunicação
> pela rede local e utilize a nuvem como suporte complementar;
>
> b) desenvolver uma API em nuvem para a persistência do histórico, a entrega
> de comandos feitos a distância e o envio de alertas ao celular;
>
> c) implementar um aplicativo móvel com alternância automática entre rede
> local, nuvem e modo offline, fila de comandos pendentes e relatórios por
> ciclo de secagem;
>
> d) validar a sincronização por carimbos de tempo e o funcionamento do
> conjunto com o controlador físico da estufa em cenários de queda de conexão.

**O 4º parágrafo** ("Para isso, a arquitetura considerada...") fica como está.

**Acrescentar no fim da Introdução, depois do 4º parágrafo:**

> Além desta introdução, o artigo está organizado em mais quatro seções. A
> seção 2 apresenta o referencial teórico, com os conceitos de Internet das
> Coisas, cura do tabaco, Computação de Borda, desenvolvimento multiplataforma,
> sincronização de dados e comunicação por API REST e notificações push. A
> seção 3 descreve a metodologia, os materiais e os métodos utilizados. A seção
> 4 apresenta e discute os resultados obtidos nos testes de validação e as
> limitações identificadas. Por fim, a seção 5 traz a conclusão e os possíveis
> trabalhos futuros.

---

## 2. METODOLOGIA — trocar dois trechos

**No 1º parágrafo** ("A metodologia adotada..."), trocar o fim da última frase
— *"...e na validação inicial da interação entre o aplicativo móvel e um
ambiente simulado de controle da estufa."* — por:

> ...e na validação da interação entre o aplicativo móvel, a nuvem e o
> controlador da estufa, primeiro em ambiente simulado e, na etapa final, com o
> controlador físico desenvolvido em projeto complementar.

**No 3º parágrafo** ("Quanto aos procedimentos técnicos..."), trocar a última
frase por:

> Já o desenvolvimento experimental corresponde à construção e à validação da
> camada de software — o aplicativo móvel e a API em nuvem —, testada
> inicialmente com um simulador desenvolvido em JavaScript e, na etapa final,
> com o controlador físico da estufa.

---

## 3. MATERIAIS E MÉTODOS — substituir os parágrafos

**Substituir o 1º parágrafo** ("Para o desenvolvimento da plataforma IoT
híbrida..."):

> Para o desenvolvimento da plataforma IoT híbrida, o sistema foi organizado em
> três elementos: o aplicativo móvel de interface com o usuário; a camada em
> nuvem, composta por uma API de persistência e sincronização e por um banco de
> dados; e o controlador físico da estufa, responsável pela leitura dos
> sensores e pela atuação local, desenvolvido em projeto complementar. O escopo
> deste trabalho é a camada de software — o aplicativo e a nuvem —, e o
> controlador é tratado como a outra ponta de um contrato de comunicação
> definido entre os dois projetos.

**Substituir o 2º parágrafo** ("Como o controlador físico da estufa será
desenvolvido..."):

> Enquanto o controlador físico estava em desenvolvimento, os testes da
> aplicação foram realizados com o apoio de um simulador desenvolvido em
> JavaScript, que reproduz o mesmo contrato de comunicação do dispositivo real,
> gerando leituras de temperatura e umidade, estados de alarme e situações de
> conexão e desconexão. Na etapa final, a validação foi repetida com o
> controlador físico, baseado no microcontrolador ESP32 e montado em placa
> definitiva para os testes.

**Substituir o 3º parágrafo** ("O aplicativo móvel foi desenvolvido..."):

> O aplicativo móvel foi desenvolvido com o framework Flutter e a linguagem
> Dart, gerando uma aplicação Android a partir de uma base de código
> multiplataforma. Ele apresenta a temperatura, a umidade, o estado de conexão e
> os alertas da estufa, permite alterar os ajustes de temperatura e umidade e
> mantém, em um banco de dados local (Isar), o cadastro das estufas, o
> histórico de leituras e eventos de cada ciclo de secagem e a fila de comandos
> ainda não entregues ao controlador.

**Inserir um parágrafo novo logo depois** (a nuvem, que no texto atual está "a
ser definida"):

> A camada em nuvem foi implementada em Node.js com o framework Express e
> hospedada na plataforma Render. O histórico é armazenado em um banco de dados
> PostgreSQL gerenciado (Supabase), e as notificações ao celular são enviadas
> pelo Firebase Cloud Messaging. A API recebe as leituras enviadas pelo
> controlador, grava o histórico, entrega ao controlador os comandos feitos a
> distância e monitora o silêncio de cada controlador, avisando o produtor
> quando ele deixa de se comunicar e quando volta.

**Substituir o 4º parágrafo** ("A arquitetura do software foi pensada para
operar de forma híbrida..."):

> A comunicação prioriza a rede local. O aplicativo consulta primeiro o
> controlador na rede Wi-Fi da propriedade e, quando ele não responde, recorre
> à API em nuvem; sem nenhum dos dois, passa ao modo offline, mantendo na tela
> os últimos valores conhecidos e guardando os comandos para envio posterior. O
> modo ativo — local, nuvem ou offline — é exibido permanentemente na
> interface.

**Substituir o 5º parágrafo** ("A sincronização das informações foi
planejada..."):

> A sincronização das configurações utiliza carimbos de tempo com a estratégia
> de última escrita vence, aplicada por campo: o ajuste de temperatura, o ajuste
> de umidade e o silenciamento do alarme carregam, cada um, o seu próprio
> carimbo. Na reconexão, o controlador aplica apenas as alterações mais
> recentes que as suas, e um comando antigo não sobrescreve uma configuração
> feita depois dele — inclusive a feita diretamente nos botões do controlador.

**Seção 3.2.1 (Ambiente de simulação):** pode ficar como está.

**Substituir a seção 3.2.2 inteira** — o título passa a ser *"3.2.2 Integração
com o controlador físico"*:

> A integração com o controlador físico, desenvolvido em projeto complementar,
> foi realizada na etapa final do trabalho. O controlador, baseado no
> microcontrolador ESP32, lê a temperatura, a umidade e o sensor de chama,
> executa localmente a lógica de alarme e disponibiliza os dados ao aplicativo
> pela rede local e à API em nuvem pela internet. Como o simulador seguia o
> mesmo contrato de comunicação, a troca não exigiu mudanças na arquitetura do
> aplicativo ou da API.
>
> Os testes seguiram uma matriz de cenários derivada dos objetivos do trabalho
> — operação sem internet, comandos offline e sincronização, acesso remoto,
> alertas com o aplicativo aberto e fechado, e o registro de uma estufada
> completa —, cada um registrado com data, horário, capturas de tela do
> aplicativo e fotografias do visor do controlador. A camada de software conta
> ainda com testes automatizados no aplicativo e no servidor, executados a cada
> alteração do código.

---

## 4. ANÁLISE DE DISCUSSÕES E RESULTADOS — substituir o texto-modelo

> Como resultado deste trabalho, a camada de software da plataforma — o
> aplicativo móvel e a API em nuvem — foi implementada e validada em conjunto
> com o controlador físico da estufa. O objetivo principal, manter o
> monitoramento e o controle da estufa mesmo com a conexão instável, foi
> atingido: nos testes, o acompanhamento não foi interrompido pela falta de
> internet, os comandos feitos sem conexão chegaram ao controlador na
> reconexão, e o histórico de uma estufada completa foi reconstituído a partir
> da nuvem. O Quadro 1 resume os cenários validados.

**Quadro 1 — Cenários de validação da plataforma**

| Cenário | Resultado | Data |
|---|---|---|
| Operação sem internet | Com o roteador desligado, o controlador manteve leitura e alarme; na volta da rede, reconectou sozinho e o aplicativo retomou a comunicação sem intervenção | 14/09/2026 |
| Comandos offline e sincronização | Ajuste feito sem conexão ficou na fila do aplicativo e foi aplicado pelo controlador após a reconexão, sem perda | 14/09/2026 |
| Acesso remoto | Leitura e comandos pela nuvem, com o celular em dados móveis, fora da rede do controlador | 13–14/09/2026 |
| Alertas com o aplicativo fechado | Notificações de temperatura fora da faixa, de controlador sem comunicação e de retorno da comunicação | 13–14/09/2026 |
| Registro de uma estufada completa | Ciclo de 39 h 39 min com 265 leituras, 4 alarmes e relatório em PDF e CSV | 12–14/09/2026 |
| Pareamento e revogação de acesso | Celular autorizado passou a comandar a estufa; após a revogação, perdeu o acesso | 05/08 e 14/09/2026 |

> **Operação híbrida.** A alternância entre rede local, nuvem e modo offline
> ocorreu de forma automática e sempre visível ao usuário. Com o celular na
> mesma rede do controlador, um ajuste enviado pelo aplicativo foi confirmado e
> apareceu no visor do controlador em poucos segundos. No teste de queda de
> internet, o controlador continuou operando sozinho — como previsto pelo
> paradigma de Computação de Borda discutido na seção 2.3 — e, restabelecida a
> rede, voltou a se comunicar sem nenhuma ação do produtor. Com o celular fora
> da propriedade, em dados móveis, o aplicativo passou ao modo nuvem e manteve
> leitura e comando.

> **Sincronização e fila offline.** No teste de 14/09/2026, com o celular sem
> nenhuma conexão, o ajuste de temperatura foi alterado de 60 °F para 70 °F. O
> aplicativo registrou o comando como pendente e informou ao usuário que ele
> seria enviado depois. Ao reconectar, a fila foi enviada pela nuvem, e o
> controlador passou a reportar o novo ajuste às 11:03:47 — confirmado pela
> fotografia do visor às 11:04:12 e pela fila zerada no aplicativo. Durante a
> espera, o aplicativo manteve na tela o valor pedido com o aviso de que
> aguardava a estufa, de modo a não sugerir que o comando havia se perdido. A
> resolução por carimbos de tempo impediu que comandos antigos sobrescrevessem
> ajustes posteriores, inclusive os feitos nos botões do próprio controlador.

> **Histórico e relatórios.** A nuvem grava uma leitura a cada dez minutos
> durante o ciclo de secagem e, imediatamente, sempre que o alarme ou o ajuste
> mudam, o que mantém o banco enxuto sem perder os momentos relevantes. O
> relatório de cada estufada une o histórico da nuvem ao registro local do
> aplicativo e apresenta resumo, linha do tempo de eventos e gráfico das
> leituras sobre a linha de ajuste, com exportação em PDF — uma leitura por
> hora, para permanecer legível — e em CSV, com todas as leituras. A estufada
> usada na validação (Quadro 1) ficou quase dois dias em operação, a maior parte
> com o aplicativo fechado, e o relatório reconstituiu o período inteiro a
> partir da nuvem, incluindo um alarme ocorrido com o aplicativo fechado e a
> sirene desligada. Esse teste de longa duração cumpriu também o papel de
> revelar falhas: na primeira execução, o relatório não incorporava o histórico
> da nuvem e exibia uma noite inteira sem leituras, embora os dados estivessem
> gravados; corrigida a busca no aplicativo, o período passou a aparecer
> completo.

> **Alertas de segurança.** As notificações chegaram ao celular com o
> aplicativo fechado: temperatura fora da faixa, controlador sem comunicação e
> retorno da comunicação. O limiar de desvio de 8 °F, para cima ou para baixo,
> é o mesmo no controlador, no servidor e em todas as telas do aplicativo —
> alarme, indicador, gráfico e eventos do relatório —, de modo que nenhuma parte
> do sistema aponta como problema o que outra trata como normal. O registro do
> alarme é independente da sirene: desligar o som no controlador não apaga o
> alarme do histórico nem impede a notificação, pois são canais distintos.

> **Testes automatizados.** Ao fim do desenvolvimento, a camada de software
> contava com 230 testes automatizados no servidor e 196 no aplicativo,
> executados a cada alteração, o que permitiu corrigir as falhas encontradas em
> campo sem reintroduzir as já resolvidas.

> **Limitações.** Os testes foram realizados em ambiente residencial, com o
> controlador em bancada, e não em uma estufa em plena safra; as temperaturas
> medidas foram, portanto, as do ambiente. Um comando feito pela nuvem depende
> da consulta periódica do controlador e pode levar até cerca de vinte segundos
> para ser aplicado — espera sinalizada ao usuário. Quando o controlador fica
> sem internet, suas leituras deixam de chegar à nuvem naquele período; o
> registro local do aplicativo cobre o intervalo apenas se ele estiver aberto na
> rede da propriedade. Por fim, a versão para iOS foi prevista na base de código,
> mas não validada, por falta de dispositivo Apple.

*Sugestões de figura para esta seção (numerar conforme o template):*
- *Figura — o controlador físico usado na validação* (a foto do visor mostrando
  o ajuste; serve para o teste de sincronização).
- *Figura — tela de monitoramento do aplicativo* (com o selo LOCAL ou NUVEM).
- *Figura — relatório da estufada* (o gráfico ou a primeira página do PDF da
  #22).

---

## 4b. Referências conferidas (15/09/2026)

Cada uma foi aberta e conferida na fonte. **Só citar o que foi lido** — é o que
sustenta a citação na banca.

**Fielding (2000) — REST.** Tese de doutorado, pública no site da universidade.
O autor tem o PDF completo (`fielding_dissertation.pdf`, baixado em 15/09).
- Onde está: capítulo 5, **seção 5.1.2 Client-Server (p. 78)** e **5.1.3
  Stateless (p. 78–79)**.
- 5.1.2: separa a interface (cliente) dos dados (servidor); a interface fica
  portável entre plataformas e cada lado evolui sem depender do outro.
- 5.1.3: cada requisição leva **toda a informação necessária** e não usa
  contexto guardado no servidor; o estado fica no cliente. Ganhos: visibilidade,
  **confiabilidade (facilita a recuperação de falhas parciais, p. 79)** e
  escalabilidade. Custo: dados repetidos em cada requisição.
- Referência, no modelo de tese do manual da faculdade (item 2.1.15.14), com
  o endereço oficial (162 folhas numeradas, conferido no PDF):
  > FIELDING, Roy Thomas. **Architectural styles and the design of
  > network-based software architectures**. 2000. 162 f. Tese (Doutorado) -
  > Information and Computer Science, University of California, Irvine, 2000.
  > Disponível em: https://ics.uci.edu/~fielding/pubs/dissertation/top.htm.
  > Acesso em: 15 set. 2026.
- Em inglês e em PDF, pode: o manual não proíbe e dá exemplo de e-book em PDF.
  Título na referência fica no original; no texto, citação **indireta** em
  português (sem marca). Citação direta traduzida levaria "tradução nossa".
- O livro de Sistemas Distribuídos da Minha Biblioteca **não trata de REST**
  (conferido pelo autor em 15/09) — o Fielding fica sozinho na 2.6.

**Google — Firebase Cloud Messaging.** Documentação oficial; a página se chama
"Firebase Cloud Messaging" e o descreve como solução de mensagens entre
plataformas para enviar mensagens de forma confiável.
  > GOOGLE. **Firebase Cloud Messaging**. Firebase documentation. [s.d.]a.
  > Disponível em: https://firebase.google.com/docs/cloud-messaging. Acesso em:
  > 15 set. 2026.

Com duas referências GOOGLE sem data, diferenciar por letra no texto e na lista,
na ordem alfabética dos títulos: **Firebase = [s.d.]a**, **Flutter = [s.d.]b**
(a citação do Flutter na 2.4.1 passa a ser "(GOOGLE, [s.d.]b)").

**Texto sugerido para a 2.6** (com a página e o argumento da confiabilidade):
> A comunicação entre o aplicativo, o controlador e a nuvem segue o estilo
> arquitetural REST (Representational State Transfer), em que cada informação
> do sistema é tratada como um recurso acessado por requisições HTTP
> independentes entre si, sem que o servidor precise guardar o estado da
> conversa com o cliente (FIELDING, 2000, p. 78). Segundo o mesmo autor, essa
> ausência de estado no servidor também facilita a recuperação após falhas
> parciais (FIELDING, 2000, p. 79), característica relevante para um sistema que
> opera com conexão intermitente. É também o que permite ao aplicativo alternar
> entre o controlador na rede local e a API em nuvem sem mudar a forma de se
> comunicar.

**Monteiro, Mengato Junior e Lima (2020) — Sistemas distribuídos.** Está na
Minha Biblioteca da faculdade (ISBN 9786556901978; Porto Alegre: SAGAH). Serve
melhor para a **seção 2.5** (sincronização) do que para o REST: tem capítulos de
**sincronização de relógios (p. 165)**, **modelos de consistência (p. 195)**,
**gestão da replicação (p. 211)** e **tolerância a falhas (p. 225)**. Só citar
depois de ler o trecho.
  > MONTEIRO, Eduarda Rodrigues; MENGATO JUNIOR, Ronaldo Cesar; LIMA, Bruno
  > Santos de. **Sistemas distribuídos**. Porto Alegre: SAGAH, 2020.

---

## 5. CONCLUSÃO, RESUMO E ABSTRACT — reescrever até 30/10

O texto antigo destas seções foi retirado deste arquivo de propósito: ele dizia
que o push não estava implementado e que o hardware era futuro. Pelo
cronograma, a Conclusão vai até outubro; quando for escrever, a base são os
Resultados acima, e os trabalhos futuros **do escopo do app e da nuvem** são:

- enviar a fila de comandos direto ao controlador quando ele estiver na rede
  local, sem esperar a nuvem;
- validar a versão iOS;
- política de retenção de dados no banco em nuvem;
- (junto com o projeto complementar) o controlador guardar as leituras feitas
  sem internet e enviá-las depois, fechando a lacuna do histórico.
