# Agendamento de ajuste e curva de cura

> **Estado (25/07/2026):** o agendamento **de uma vez** ("às 14h deixe em
> 120 °F") está **implementado**. A curva por fases, analisada primeiro, segue
> como trabalho futuro — e o estudo dela está preservado abaixo porque explica
> por que a versão implementada ficou onde ficou.

A ideia começou como curva de cura: o aparelho trocaria o ajuste sozinho a cada
fase. Conversando, o escopo real apareceu e era outro, bem menor:

> "O produtor quer a temperatura em 120 °F daqui a duas horas, mas nessa hora
> ele não vai estar por perto."

Não é automação da cura — é um **despertador com ação**. A maioria dos
produtores olha o fumo para decidir quando erguer o calor; a tabela é
referência, não roteiro. Uma curva automática pressupõe uma regularidade que a
folha nem sempre respeita.

## O que foi implementado

Menu da estufa → **AÇÕES RÁPIDAS → "Agendar ajuste"**. Escolhe-se em quanto
tempo (atalhos de 30 min a 12 h — o produtor pensa em "daqui duas horas", não
em "às 16h13") e o valor: temperatura, e umidade se quiser.

O trabalho é **dividido entre celular e nuvem**, porque nenhum dos dois resolve
sozinho:

| Parte | Onde | Por quê |
|---|---|---|
| **O aviso** ("Hora de ajustar") | alarme local no celular | funciona **sem internet nenhuma**, o caso comum na propriedade |
| **A troca do ajuste** | agendador no servidor | funciona com o **app fechado**, que é justamente o cenário |

O Android dispara a notificação na hora marcada, mas **não roda código do app**
para enviar o comando — por isso a segunda metade não pode morar no celular. E o
servidor **não** manda push: se mandasse, o mesmo evento chegaria duas vezes.

Detalhe das rotas em `CONTRATO_API.md`. O firmware **não mudou**: um agendamento
vencido entra na mesma caixa de comandos de um ajuste feito à mão.

### Decisões que valem registro

- **Só valor absoluto na tela.** A variação relativa ("+10 °F") existiu e saiu:
  era um segundo jeito de dizer a mesma coisa, com a desvantagem de o produtor
  ter de fazer a conta de cabeça. O servidor ainda aceita relativo (validado e
  testado), resolvendo contra o ajuste vigente no instante de aplicar.
- **Os seletores abrem no ajuste que já está valendo**, e os botões de + e −
  são os mesmos do painel de monitoramento (seguram para andar depressa).
- **O carimbo do LWW é a hora agendada, não a hora em que aplicou.** Um
  agendamento que vence atrasado (servidor fora do ar) não pode desfazer um
  ajuste que o produtor tenha feito à mão nesse meio tempo. Com a hora agendada,
  o mecanismo que já existia resolve sozinho: o mais novo vence.
- **Sem internet ao agendar**, o aviso local é armado e o registro na nuvem é
  **retentado** ao abrir o app e ao entrar na tela. Se vencer sem nunca ter sido
  registrado, o agendamento é descartado (aplicar "120 °F às 10:30" às 11:15
  passaria por cima de quem já está na fornalha) — e o produtor **é avisado**,
  em vez de o item sumir calado.
- **O lembrete tem card próprio** nas notificações ("Ajuste agendado"), com os
  mesmos dois interruptores dos outros eventos. Desligar "Notificar" **não**
  desliga o agendamento: o ajuste continua sendo aplicado, só o lembrete some.
  O "Tocar" nasce **desligado** — alarme é para problema, e um lembrete que o
  próprio produtor marcou não é problema; quem precisa ser acordado às 3h para
  pôr lenha liga o interruptor.
- **A tela abre sempre no primeiro atalho** (30 min), e não com uma escolha já
  feita: é o prazo que menos surpreende se alguém tocar em "Agendar" sem reparar.
- **O texto do topo separa as duas metades**, porque elas têm exigências
  diferentes: o aviso chega sem internet nenhuma; a troca do ajuste passa pela
  nuvem e pode não acontecer se o celular nunca registrar ou o aparelho ficar
  offline.

### Comportamento nas falhas

| Situação | Aviso | Ajuste |
|---|---|---|
| Tudo funcionando | ✅ | ✅ |
| Celular sem internet, volta **antes** da hora | ✅ | ✅ (reenvio automático) |
| Celular sem internet, volta **depois** | ✅ | ❌ — avisa que não aplicou |
| Servidor cai e volta atrasado | ✅ | ✅ aplica, mas **perde** para ajuste manual mais novo |
| ESP sem internet na hora | ✅ | ✅ ao reconectar (fica na caixa de comandos) |

### O que o agendamento **não** faz

O aparelho não tem relé: o ajuste é a **referência do alarme**, não um comando
para a fornalha. Quem ergue o calor é o produtor, com a lenha. Por isso o aviso
existe — e por isso o recurso não cria risco de incêndio, já que nada nele
injeta calor.

Se depois de aplicado a estufa demorar a subir (pouca lenha), o ajuste **é
mantido** — e passados os 5 min de acomodação o alarme de temperatura baixa
dispara, que é exatamente o que se quer saber.

---

## Estudo original: curva por fases (trabalho futuro)

O que segue é a análise que levou ao recorte acima. A curva automática continua
sendo trabalho futuro.

## O que este recurso pode e não pode fazer

**O aparelho não aquece a estufa.** O ESP32 tem LEDs, buzzer e display — não tem
relé nem atuador. O "ajuste" de temperatura não comanda a fornalha: ele é a
**referência do alarme**. Quem muda a temperatura de fato é o produtor, na
fornalha, com o soprador.

Portanto, agendar aqui significa **agendar a troca da referência do alarme**, e
não o aquecimento. Isso continua sendo útil — hoje, se o produtor troca de fase e
esquece de subir o alvo, o alarme reclama sem motivo; e se esquece de descer, ele
cala quando não deveria. O agendamento faz o alarme acompanhar a fase sozinho.

Vantagem de segurança: como **não injeta calor**, o recurso não cria risco de
incêndio. É o oposto de um agendamento que ligasse a fornalha sozinho.

Um agendamento que de fato **controle** a estufa depende de relé/atuador — está
listado como bloqueado por hardware no `HANDOFF.md`.

## Onde o agendamento pode morar

| Lugar | Custo | Confiabilidade |
|---|---|---|
| **App** (o celular dispara na hora) | baixo | **ruim** — o Android suspende timers em segundo plano (Doze), e o celular pode estar desligado ou fora de alcance. Numa cura de 5 a 7 dias isso falha. |
| **Nuvem** (o servidor agenda) | médio-baixo — a caixa de comandos já existe e o aparelho já busca a cada 20 s | média — exige internet na propriedade **no momento da troca**; sem ela o comando chega atrasado. |
| **Firmware** (o aparelho se vira) | alto — mexe em três camadas e exige regravar | **melhor** — funciona sem internet e sobrevive a queda de energia (NVS). |

**Recomendação: firmware.** A tese do projeto é *edge-first* — o aparelho é a
fonte da verdade e opera sem internet. Um agendamento que só funciona com
internet contradiz o próprio argumento defendido no TCC.

## Tempo relativo, não relógio

A forma proposta é contar **a partir do início da estufada**:

```
Fase 1  90 °F / 100 %  por 24 h
Fase 2 100 °F /  90 %  por 12 h
Fase 3 ...
```

Três motivos:

1. **Dispensa NTP.** O firmware só tem hora real quando alcança a internet
   (`configTime` com `pool.ntp.org`); sem ela, `nowMs()` cai para o `millis()`.
   Um agendamento por relógio ficaria refém justamente do que pode faltar.
2. **É como a cura é descrita.** O produtor fala em "48 horas de amarelecimento",
   não em "às 15h".
3. **Sobrevive à queda de energia**, se o tempo decorrido for persistido na NVS —
   ao voltar, o aparelho sabe em que ponto da cura estava.

## Dificuldade real

O ponto mais chato não é a lógica do agendamento, é a **sincronização**: o
`POST /sincronizar` e o LWW trabalham hoje com **campos simples** (um valor e um
timestamp por campo). Uma curva é uma **lista de fases** — exige decidir como
versioná-la e resolver conflito entre app e aparelho, além de espaço na NVS e no
flash. É a maior funcionalidade discutida até agora, cruzando app, servidor e
firmware.

**Com o TCC a poucas semanas, não é hora de começar.** Fica como trabalho futuro
com o desenho pronto — o que, na defesa, conta a favor.

## Passo intermediário: presets de fase (barato)

Já existe "Preparar nova estufada" (90 °F / 100 %), que é exatamente um preset.
Generalizando, as ações rápidas ganhariam um botão por fase da cura:

> Amarelecimento · Fixação da cor · Secagem da folha · Secagem do talo

Cada um aplica o alvo daquela fase **na hora**, num toque. Sem cronômetro, sem
firmware novo, funciona offline (é um comando como qualquer outro) e entrega boa
parte do valor prático — o produtor troca de fase quando **vê** que a folha
pediu, que é como a cura acontece de verdade. A automação por tempo pressupõe uma
regularidade que a folha nem sempre respeita.

## Pendências antes de implementar

- **Valores de cada fase** (temperatura e umidade): conhecimento do produtor,
  não do software. Sem eles os presets não saem do papel.
- **Ajustes de escopo** que o produtor ainda quer comentar.
- Definir se os presets pedem confirmação (mudar o alvo no meio de uma estufada
  altera quando o alarme dispara).
