# Plano de banco de dados

Este documento define o que deve ser guardado no banco do Sentinela Smart e o
que deve ficar apenas como leitura temporaria no app.

## Objetivo

O banco deve ajudar a explicar uma estufada depois que ela aconteceu.

Ele nao deve tentar gravar tudo em tempo real. A tela do app pode atualizar com
frequencia, mas o historico precisa guardar somente dados uteis para relatorio,
auditoria e sincronizacao.

## O que ja existe

O schema atual possui:

- `dispositivos`: identifica simulador ou hardware real.
- `configuracoes`: guarda os ajustes atuais e timestamps usados na regra de
  sincronizacao.
- `leituras`: guarda snapshots de temperatura, umidade, alarmes, estado e
  origem da leitura.
- `comandos_sync`: guarda comandos pendentes ou enviados pelo app/hardware.

A origem dos dados deve ficar rastreavel:

- `dispositivos.tipo_dispositivo`: `simulador` ou `hardware`;
- `leituras.fonte`: `simulador`, `hardware` ou `manual`.

## Politica de armazenamento

### Leituras normais

Durante uma estufada ativa, salvar uma leitura periodica em intervalo maior.

Regra inicial:

```text
1 leitura a cada 10 minutos durante a estufada
```

Isso evita sobrecarregar o banco e ainda gera pontos suficientes para relatorio.

### Leituras importantes

Salvar imediatamente quando acontecer algo relevante:

- alarme acionado;
- alarme normalizado;
- oscilacao relevante em relacao ao ajuste;
- falha de leitura do sensor;
- perda ou retorno de conexao;
- queda ou retorno de energia, quando o hardware informar;
- mudanca de ajuste de temperatura;
- mudanca de ajuste de umidade.

### Fora de uma estufada

Quando nao houver estufada em andamento, evitar salvar leituras historicas.

O app ainda pode mostrar a leitura atual, mas ela nao precisa virar relatorio.

Excecoes possiveis:

- salvar ultimo estado conhecido para mostrar na home;
- salvar evento critico de seguranca, se fizer sentido para o projeto.

## Estufadas

Uma estufada representa o periodo entre colocar fumo verde na estufa e retirar o
fumo curado.

Campos planejados:

- dispositivo/estufa;
- data e hora de inicio;
- data e hora de fim;
- status: em andamento, finalizada ou cancelada;
- ajuste inicial de temperatura;
- ajuste inicial de umidade;
- ultimo ajuste de temperatura;
- ultimo ajuste de umidade;
- origem do inicio/fim: app, hardware ou sistema.

Enquanto essa tabela nao existir, o app pode continuar controlando o ciclo
localmente, mas o banco ainda nao tera uma entidade propria para relatorios por
estufada.

### A estufada e do celular; a leitura e da nuvem

Hoje **nao existe tabela de estufadas na nuvem**. O ciclo mora so no Isar, no
celular; a nuvem guarda leituras soltas, carimbadas por horario e por aparelho,
sem saber a qual secagem pertencem.

Tres consequencias que valem estar escritas:

**Apagar uma estufada apaga so a copia local.** `apagarCiclo` remove os eventos,
as leituras daquele intervalo e o proprio ciclo — tudo no Isar, sem nenhuma
chamada ao servidor. As leituras correspondentes **continuam na nuvem**, orfas:
existem no banco, e nenhuma tela consegue mostra-las, porque toda consulta de
historico parte de um ciclo.

**Isso e escolha, nao esquecimento.** Apagar no celular apaga a *minha* copia;
apagar na nuvem apagaria a de *todo mundo* — e o acesso e compartilhavel por QR
Code, entao outro celular pode ter a mesma estufada. Entre desperdicar ~0,7 MB
(uma secagem de 10 dias sao ~1.440 linhas) e apagar o relatorio de outra pessoa
por engano, o desperdicio e o erro barato. Fazer diferente exigiria responder
"de quem e esta estufada?", e o sistema nao tem dono — tem quem tem a chave.

**Desinstalar o app perde o historico.** O Isar nasce vazio, nao ha ciclo para
selecionar, e o app nao tem como remontar um: ele nao sabe onde a secagem comecou
nem terminou. Os dados brutos sobrevivem na nuvem ate a retencao, mas so seriam
alcancaveis consultando o banco na mao, por `timestamp_origem_ms`.

*Por que a retencao e longa (300 dias), entao?* Nao e pelas orfas. E porque **o
ciclo vive muito tempo no celular**: abrir o relatorio de uma secagem de oito
meses atras faz o app buscar na nuvem para preencher os buracos do periodo em que
o app esteve fechado. A retencao acompanha a vida do ciclo, nao a das leituras.

*Trabalho futuro com motivo:* persistir o ciclo na nuvem faria o relatorio
sobreviver a troca de celular — e daria a base para responder a pergunta de
propriedade que hoje impede o apagar distribuido.

## Eventos da estufada

Eventos sao registros curtos que ajudam o produtor a entender o que aconteceu.

Eventos planejados:

- estufada iniciada;
- estufada finalizada;
- ajuste de temperatura alterado;
- ajuste de umidade alterado;
- alarme acionado;
- alarme normalizado;
- aparelho offline;
- aparelho online novamente;
- falha de sensor;
- comando aplicado;
- comando ignorado por ser antigo.

Formato sugerido:

```text
horario + tipo + descricao + severidade + origem
```

Exemplo:

```text
17:20 - Alarme acionado: temperatura alta.
17:25 - Alarme normalizado.
17:40 - Ajuste de temperatura alterado para 115°F.
```

## Regra de oscilacao

Para nao gerar evento demais, uma oscilacao so deve virar evento quando passar
de um limite relevante.

Regra inicial:

```text
temperatura: diferenca maior que 5°F em relacao ao ajuste
umidade: diferenca maior que 5% em relacao ao ajuste
```

O grafico pode mostrar pontos visuais, mas o banco deve salvar somente os
pontos que importam para explicar a estufada.

## Comandos e sincronizacao

Quando app e aparelho ficarem desconectados, comandos podem ficar pendentes.

Regra planejada:

- cada comando deve ter timestamp;
- comando mais recente vence quando dois comandos alteram o mesmo campo;
- comando antigo pode ser marcado como `ignorado`;
- comando aplicado deve receber `synced_at`.

Isso evita que uma configuracao antiga volte e desfaça uma configuracao mais
recente feita pelo produtor.

## Tabelas futuras recomendadas

Para completar a parte de relatorio, ainda faz sentido adicionar:

- `estufadas`;
- `eventos_estufada`;
- talvez `leituras_estufada` ou uma coluna `estufada_id` em `leituras`.

A opcao mais simples e adicionar `estufada_id` em `leituras` e criar uma tabela
separada para eventos.

## O que nao salvar

Evitar:

- leitura a cada segundo;
- cada pequena variacao de sensor;
- estados visuais temporarios do app;
- dados duplicados que podem ser calculados depois;
- informacoes pessoais desnecessarias do produtor.

Essa escolha ajuda a manter o projeto simples, barato e mais facil de explicar.
