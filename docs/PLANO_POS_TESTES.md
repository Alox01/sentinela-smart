# Plano depois dos testes de campo

> Escrito em 25/07/2026, atualizado em 29/07/2026. App e servidor no ar, e o
> firmware **1.18.0 gravado** no aparelho. A ordem abaixo pressupõe que os testes de
> campo aconteçam primeiro — vários itens só fazem sentido depois deles.

## Por que testar antes de continuar

Muita coisa foi escrita em poucos dias, e o risco era ter código correto no
papel e não provado. Os testes de **notificação** já foram feitos e acharam dois
bugs que nenhum teste automatizado pegaria — um silencioso (comando parado numa
caixa que o simulador nunca consulta) e um intermitente (a resolução do nome
mDNS estourando o prazo da sonda).

Sobram os que **dependem do aparelho em campo**. O ESP já está com a **1.18.0**,
então nenhum deles espera gravação.

## 1. Testes de campo (só o produtor pode fazer)

| Teste | O que prova | Depende de |
|---|---|---|
| Segurar o botão do buzzer 3 s | liga/desliga a sirene sem celular (2 apitos × 1 longo) | 1.13.0 ✅ |
| Som contínuo no fogo | chama e temperatura de incêndio contínuos; alarme comum intermitente | 1.18.0 ✅ |
| Modo de configuração num celular real | portal cativo e IP fixo, **nunca abertos fora do código** | 1.13.0 ✅ |
| Ponte de leitura | energia sim, internet da propriedade não, celular no 4G → **sem** falso "sem comunicação" | APK |
| Cadastrar / atualizar estufa | os fluxos novos de provisionamento | APK |

### Acrescentados em 04/08/2026 — dependem de **gravar o firmware**

O aparelho está com a 1.24.0. Nada abaixo existe no ESP até ele ser regravado.

| Teste | O que prova | Como saber que falhou |
|---|---|---|
| Segurar os 3 botões | os LEDs acendem **enquanto conta** e o apito só vem ao entrar; a contagem aguenta o dedo escorregando | LED não acende, ou a contagem parece loteria como antes |
| Entrar em configuração logo depois de uma leitura | a nuvem espera enquanto os 3 botões estão na mão | segurar 3 s não faz nada, aleatoriamente |
| Configurar numa rede **sem senha** | `semsenha=1` grava senha vazia de propósito | o aparelho não conecta e não diz por quê |
| Salvar pelo app numa rede com senha | senha vazia continua mantendo a atual | o aparelho some da nuvem depois de salvar |

E, sem depender de gravação:

| Teste | O que prova |
|---|---|
| Abrir o relatório de uma estufada **encerrada há mais de uma hora** | o gráfico desenha linha e pontos (era o caso que abria vazio) |
| Abrir "Relatórios" logo depois do monitoramento | entra sem o giro de carregamento |
| Compartilhar acesso por QR num segundo celular | o único caminho que sobrou; sem convite escrito não há reserva |

### Desembaraçar as três estufas (29/07/2026) — **primeiro de todos**

As três estufas cadastradas ficaram apontadas para o **mesmo aparelho** (o ESP
real), então os três cartões espelhavam o mesmo display. Causa em
`HANDOFF.md`: o app aprendia o `idHardware` de quem atendesse no endereço e
sobrescrevia o que já sabia, e endereços repetidos fizeram três estufas virarem
uma. Enquanto isso não for desfeito **à mão**, nada mais medido na lista de
estufas significa coisa alguma.

| Estufa | Endereço | ID do aparelho |
|---|---|---|
| Esp32-1 (real) | nome mDNS dele | `ESP32_215788` |
| Esp32-2 (do primo) | o do aparelho **dele** | vazio — aprende ao conectar lá |
| Estufa L (simulador) | qualquer um, diferente dos outros | `ESP32_REALISTIC_V2` |

O simulador **precisa** do id digitado: não existe aparelho na rede para ser
descoberto. Foi o que fez o cartão dele dizer OFFLINE depois de trocar o
endereço — e o motivo de a mensagem virar "SEM ID".

Depois de arrumar, o que provar: **cada cartão com números próprios**, e o
Esp32-1 parando de piscar entre LOCAL e NUVEM (a histerese de duas falhas).

| Teste | O que prova |
|---|---|
| Salvar duas estufas no mesmo endereço | é **recusado**, com explicação |
| Cartão sem id | diz **SEM ID**, não OFFLINE |
| Detalhes da conexão | mostram a versão do firmware e o id do aparelho |

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
| Versão do firmware pela nuvem | ✅ 1.17.0 confirmada de fora, sem terminal na rede local |
| **Queda de energia** (29/07/2026) | ✅ passou inteiro: o "sem comunicação" chegou no prazo, o ajuste **voltou do NVS** (não nos valores padrão) e o aviso de retorno chegou ao religar |
| Chave própria registrada na nuvem (TOFU, 1.18.0) | ✅ o aparelho registrou sozinho, no ciclo de comandos, sem intervenção |
| Desembaraçar as três estufas | ✅ feito à mão pelo produtor |
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
celular real, queda de energia, hold de 3 s e a ponte de leitura.

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

## 3. Decisão do limiar de incêndio — **fechada** (29/07/2026)

**Fica em 175 °F.** O produtor mediu o que faltava: atiçar a fornalha passa do
ajuste em **não mais de 2 °F**, e só passa disso com clima muito quente, ajuste
em 160 °F e fumo quase seco. Com 160 + 2, sobram 13 °F até o limite — o alarme
falso que a inferência previa não acontece. Velocidade de subida e "sustentado
por N minutos" foram descartados antes, também por evidência dele. Detalhes e o
raciocínio em `AMBIENTE_ESTUFA.md` §3.

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
