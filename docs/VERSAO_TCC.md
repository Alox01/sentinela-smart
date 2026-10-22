# A versão apresentada no TCC

Branch `tcc-versao-simplificada`, aberta em 21/10/2026 a partir de
`test/http-local-device` (a branch de produção, de onde o Render publica e de
onde o produtor instala o app).

Ela existe para que o que é apresentado e o que é explicado sejam **a mesma
coisa**. Antes, uma marca de compilação (`ESCOPO_TCC`) escondia da interface o
que estava fora dos objetivos declarados; o código continuava lá, e o trabalho
ficava na posição desconfortável de descrever um sistema e demonstrar outro,
maior. Aqui o que saiu, saiu do código.

**A versão completa não foi perdida.** Ela continua em
`test/http-local-device`, e a tag `completo-pre-simplificacao-2026-10-22` marca
o ponto exato de onde esta branch partiu — no repositório e no `sentinela`.

## O que saiu, e por quê

### Agendamento de ajuste

Marcar "às 14h deixe em 120 °F". Não está em nenhum dos cinco objetivos do
trabalho — é automação de curva de cura, que o texto trata explicitamente como
trabalho futuro (`AGENDAMENTO_CURA.md`). Levou junto a tela, o serviço, as rotas
do servidor, a tabela `comandos_agendados`, as permissões de alarme exato do
Android e a dependência `timezone`.

A tabela continua existindo no banco em nuvem, de propósito: a branch de
produção ainda agenda e ainda escreve nela.

### Compartilhar acesso por QR Code

Um celular que já tem a chave gerava um QR Code; a câmera do outro celular lia e
cadastrava a estufa com a chave dentro.

Era o único ponto do sistema que contradizia a frase que o capítulo de
autenticação defende: **só comanda quem esteve na frente do aparelho**. Com o
QR, o acesso atravessava a cidade.

O segundo celular continua tendo um caminho — "pegar acesso", que lê a chave do
próprio aparelho com o PIN que aparece no visor. É presença física, que é
exatamente o que o texto afirma.

**A revogação ficou.** Ela é a outra metade da mesma regra (presença física para
dar, presença física para tirar) e é a resposta para "e se o senhor vender o
aparelho?".

### A seção "Ações rápidas" do menu

Três itens: agendar ajuste (acima), reiniciar ajustes do aparelho e apagar
estufadas. O segundo é atalho para o que o + e o − da tela principal já fazem; o
terceiro é porta duplicada — a lixeira da tela de relatórios faz o mesmo, e é
onde se procura. Nenhuma capacidade se perdeu.

### O filtro de período do relatório

Tinha início e fim independentes, cada um com data, hora e minuto, intervalo
mínimo de uma hora, limpar filtro e os avisos de intervalo inválido. Cada par de
campos era um caso: só o início preenchido, só o fim, fim antes do início,
intervalo curto demais, e uma exportação cujo conteúdo ninguém previa olhando a
tela.

O que se faz com aquilo é sempre a mesma coisa: olhar **um dia** da estufada.
Agora é um dia de cada vez, com setas para o anterior e o seguinte. O PDF e o
CSV continuam saindo com a estufada inteira, e a tela diz isso.

### Três rotas e um simulador que simulava demais

Rotas sem nenhum chamador, e no simulador um sorteio de eventos meteorológicos
(chuva, sol forte, vento) que empurrava temperatura e umidade. Realismo que o
trabalho não demonstra e que tornava os números da tela impossíveis de
justificar numa pergunta.

## O que **não** saiu

Nada do núcleo declarado: leitura dos dois sensores, controle do forno, alarme
de temperatura e de chama, operação offline com fila de comandos, acesso remoto
pela nuvem, notificações push com o app fechado, relatório com gráfico, eventos,
PDF e CSV, múltiplas estufas, configuração do aparelho pelo app e revogação de
acesso.

Nenhum defeito de campo corrigido foi revertido. Os testes que guardam cada um
deles continuam no lugar.

## Os números

| | Produção | Apresentada |
|---|---|---|
| App (`lib`, sem gerados) | 16.793 linhas | 14.645 |
| Servidor (sem testes) | 4.808 linhas | 4.169 |
| Arquivos Dart | 82 | 74 |
| Testes do app | 36 arquivos | 31 |
| Testes do servidor | 26 arquivos | 24 |

Verificado em 22/10/2026, com `flutter analyze` limpo, 163 testes do app e 202
do servidor passando.

## Como gerar o APK desta branch

Não existe `--dart-define=ESCOPO_TCC` aqui. Sai um APK só:

```
flutter build apk --release --split-per-abi --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

## O que ainda falta antes de apresentar

- [ ] Instalar este APK no celular e percorrer o roteiro: troca entre duas
      estufas, dia anterior e seguinte, eventos do dia, PDF e CSV da estufada
      inteira, operação sem internet, fila offline e reconexão, acesso remoto,
      notificação com o app fechado, revogação de acesso.
- [ ] Conferir o PDF e o CSV gerados — não só se o botão funciona: período,
      número de leituras, eventos e duração têm de descrever o ciclo completo.
- [ ] Refazer as capturas de tela da apresentação que ainda mostram
      agendamento, QR Code ou o filtro antigo de hora e minuto.
- [ ] Criar a tag da versão apresentada depois do teste em campo.
