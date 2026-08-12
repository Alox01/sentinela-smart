# Índice da documentação

São 27 arquivos. Este índice existe para ninguém abrir seis para achar um — e
para separar o que **vale hoje** do que é **registro do que já foi**.

## Comece por aqui

| Se você quer… | Leia |
|---|---|
| mexer no código | **`CONVENCOES.md`** — regras de commit, comandos de build, e os fatos de domínio que parecem bug e não são |
| saber o estado do projeto | **`HANDOFF.md`** |
| pegar a próxima tarefa | **`AUDITORIA.md`** — é a fila de trabalho, com caixas |

## O sistema como ele é

- **`CONTRATO_API.md`** — o JSON que app, aparelho e nuvem falam entre si. É a
  referência de quem mexe em qualquer uma das três pontas.
- **`CONFIGURACAO_ESP32.md`** — pinagem, modo de configuração, endereçamento na
  rede, chave por aparelho e PIN de emparelhamento. O maior e o mais consultado.
- **`NOTIFICACOES_PUSH.md`** — quais avisos existem, quem acorda de madrugada, e
  a pegadinha dos canais do Android que estão congelados desde a criação.
- **`HISTORICO_FIRMWARE.md`** — o que cada versao do firmware mudou e por que.
  Morava no topo do `.ino`; o motivo medido em campo esta aqui, o *quando* esta
  no `git log`.
- **`AMBIENTE_ESTUFA.md`** — como é a propriedade e a estufa. Sem isso, decisão
  de limiar e de sensor vira chute.
- **`SEGURANCA.md`** e **`SEGURANCA_COMANDOS.md`** — o modelo de ameaça e o
  emparelhamento por PIN.
- **`PLANO_BANCO_DADOS.md`** — o que é guardado, por quanto tempo e por quê.

## Planos e filas

- **`AUDITORIA.md`** — dívida técnica, com progresso marcado.
- **`PLANO_POS_TESTES.md`** — testes de campo e o que cada um provou.
- **`ROADMAP_PRE_APK.md`** — o que precedeu o primeiro APK. Histórico.

## Trabalho futuro (nada disso está construído)

- **`HUB_LORA.md`** — o rádio para levar a leitura até a lavoura, onde não há
  internet. Leia o aviso do topo: há duas pernas de rádio, e só uma justifica o
  projeto.
- **`AGENDAMENTO_CURA.md`** — curva de cura por fases, além do agendamento
  simples que já existe.
- **`SUPRESSAO_INCENDIO.md`** — atuação contra fogo, não só aviso.
- **`VIABILIDADE_COMERCIAL.md`** — se um dia virar produto.

## TCC

- **`MAPA_DO_CODIGO.md`** — o que responder quando perguntarem "qual biblioteca
  você usou para isso?" ou "onde está a lógica do alarme?". Feito para ler uma vez
  antes de apresentar.

- **`ARTIGO_TCC_OUTLINE.md`** e **`ARTIGO_CONTINUACAO.md`** — estrutura e
  rascunhos do texto.
- **`DIAGRAMAS.md`** — DER, arquitetura, sequência e o modelo local.

## Apoio a quem desenvolve

- **`IOS.md`** — o que já está configurado para iPhone, o que só se resolve com
  um Mac, e por que a falta de duas chaves no `Info.plist` mata a rede local sem
  dar erro nenhum.
- **`EXECUCAO_LOCAL.md`** — subir servidor e app na máquina.
- **`ESP32_VIRTUAL.md`** e **`TESTE_ESP32_REAL.md`** — testar com e sem aparelho.
- **`DEMO.md`** — roteiro de demonstração.
- **`NUVEM_POR_APARELHO.md`** — como um aparelho vira estado na nuvem.

## Quando o documento e o código divergem

Quando um documento contradiz o código, **o código está certo** — e o documento
virou dívida. Corrija-o no mesmo commit.
