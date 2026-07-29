# Plano depois dos testes de campo

> Escrito em 25/07/2026, com o app e o servidor no ar e o firmware 1.15.0
> compilado mas **ainda não gravado**. A ordem abaixo pressupõe que os testes de
> campo aconteçam primeiro — vários itens só fazem sentido depois deles.

## Por que testar antes de continuar

Muita coisa foi escrita em poucos dias, e o risco era ter código correto no
papel e não provado. Os testes de **notificação** já foram feitos e acharam dois
bugs que nenhum teste automatizado pegaria — um silencioso (comando parado numa
caixa que o simulador nunca consulta) e um intermitente (a resolução do nome
mDNS estourando o prazo da sonda).

Sobram os que **dependem do aparelho em campo**. O ESP está com a **1.13.0**; a
**1.15.0** (silêncio de 10 min valendo para fogo, e fogo tocando contínuo)
ainda precisa ser gravada.

## 1. Testes de campo (só o produtor pode fazer)

| Teste | O que prova | Depende de |
|---|---|---|
| Segurar o botão do buzzer 3 s | liga/desliga a sirene sem celular (2 apitos × 1 longo) | 1.13.0 ✅ |
| Som contínuo no fogo | chama e >175 °F contínuos; alarme comum intermitente | 1.16.0 |
| Modo de configuração num celular real | portal cativo e IP fixo, **nunca abertos fora do código** | 1.13.0 ✅ |
| Queda de energia | o ajuste volta da NVS, e o watchdog avisa | 1.13.0 ✅ |
| Agendar com o ESP real | lembrete chega **e** o ajuste muda sozinho (o simulador já provou a lógica) | APK + servidor |
| Ponte de leitura | energia sim, internet da propriedade não, celular no 4G → **sem** falso "sem comunicação" | APK |
| Cadastrar / atualizar estufa | os fluxos novos de provisionamento | APK |

**O que anotar em cada um:** o que aconteceu, quanto tempo levou e se o app
estava aberto ou fechado. Esses números viram a seção de resultados do TCC — e,
se algo falhar, são eles que dizem se o problema é canal, permissão ou
preferência.

### Resultados já obtidos (25/07/2026)

| Teste | Resultado |
|---|---|
| Lembrete de agendamento (simulador) | ✅ chegou na hora marcada |
| Agendamento aplicar o ajuste (simulador) | ❌ **falhava** — o agendador jogava na caixa que só aparelho real consulta. Corrigido e coberto por teste. |
| Silêncio de 10 min durante fogo (1.15.0, campo) | ✅ cala — mas achou o furo abaixo |
| Fogo **começando** dentro dos 10 min silenciados | ❌ **não tocava nada**. O silêncio cobria fogo de que o produtor nunca ficou ciente. Corrigido na 1.16.0 e ✅ **confirmado em campo**. |
| Nome da estufa no push | ✅ chegou "Esp32-2 · …", teste e alarme real |
| Alarme com "Não perturbe" ligado | ✅ **toca** — a permissão de furar o DND funciona |
| Alarme no modo silencioso | ❌ não toca (limitação do Android, ver `NOTIFICACOES_PUSH.md`) |
| Alarme no modo vibrar | vibra, não toca |
| Conexão local pelo nome mDNS | ⚠️ caía na nuvem por alguns segundos, de forma **intermitente**. Causa: a resolução do nome estourava o timeout de 2 s da sonda. Corrigido (4 s só para nomes). |
| "Temperatura muito elevada" (leitura falsa via `POST /leitura`) | ✅ chegou como alarme, com título próprio, separado do incêndio |
| O mesmo aviso com "Tocar" **desligado** | ✅ chegou como notificação comum — o interruptor faz o que promete |
| Sirene parando ao abrir o app | ✅ depois de trocar a seleção de canais por `cancelAll()` |

**Como testar sem o aparelho:** `POST /leitura` com um `idHardware` real e
`riscoIncendio: true` (ou `perigoChama: true`) dispara o alerta com o ESP
desligado — o servidor lê o estado direto do corpo. Como o aviso sai na **borda
de subida**, mande uma leitura normal entre um teste e outro. Isso vira leitura
de verdade: o app mostra o valor e ele pode entrar no histórico da estufada.

> **Não dá para testar push pelo simulador:** `avaliarAlertas` o ignora de
> propósito, para o aparelho de demonstração não disparar alarme.

### Os testes de notificação estão concluídos (25/07/2026)

Sobraram apenas os que dependem do aparelho em campo: modo de configuração num
celular real, queda de energia, hold de 3 s, silêncio do fogo (v1.14.0) e a
ponte de leitura.

## 2. Correções do que os testes acharem

Deixado em branco de propósito. É a razão de os itens abaixo não estarem
agendados: qualquer falha em campo tem prioridade sobre funcionalidade nova.

Dois pontos já conhecidos, que os testes podem confirmar ou derrubar:

- **Acomodação de 5 min pode ser curta** para fornalha lenta: se o alarme de
  temperatura baixa disparar sempre depois de um ajuste para cima, o valor
  precisa subir (`TEMPO_ACOMODACAO_MS`).
- **Os alarmes usam a mesma sirene.** Confirmado em teste e **decidido**: cada
  aviso ganha o seu som, o atual fica com o desvio de temperatura. Aguardando os
  áudios do produtor. Requisitos dos arquivos e a pegadinha do canal congelado
  em `NOTIFICACOES_PUSH.md`.

## 3. Decisão do limiar de incêndio

Pendente há tempo, e é **conhecimento do produtor**, não do software: os 175 °F
com máxima de trabalho em 165 °F deixam 10 °F de folga, com o sensor no ar mais
quente da estufa. Subir o limiar, ou trocá-lo por **velocidade de subida**?
Ver `AMBIENTE_ESTUFA.md` §3. Uma estufada completa observada responde isso.

## 4. Provisionamento, Parte 1 — **feito** (25/07/2026)

A tela de sucesso da configuração leva endereço e chave de volta ao formulário
de cadastro, em vez de o produtor decorar um nome como
`sentinela-215788.local`. E, quando aberta pelo menu de uma estufa já cadastrada,
oferece **atualizar** — sem isso, trocar a chave no aparelho deixava a do app
velha e os comandos passavam a ser recusados sem explicação.

Falta só testar em campo.

## 5. Escrita do TCC

O prazo que o produtor definiu era começar por volta de 08/08/2026. Os quatro
objetivos específicos estão implementados; o que falta para a escrita são os
**números dos testes** do item 1.

## Fora deste plano (trabalho futuro declarado)

- **Provisionamento Parte 2** — chave gerada pelo aparelho, TOFU. Muda o servidor
  de chave global para chave por aparelho: grande, e não bloqueia o TCC.
- **Curva de cura por fases** — ver `AGENDAMENTO_CURA.md`.
- MQTT, HTTPS no ESP, atuadores/relé, APK assinado para a Play Store.
