# Agendamento da curva de cura

> **Documento de análise, não de decisão.** Registra o estudo de viabilidade
> feito em 24/07/2026. Há ajustes de escopo ainda a discutir com o produtor —
> nada aqui está fechado.

Ideia levantada: agendar mudanças de temperatura e umidade nas "ações rápidas"
do menu da estufa, para a cura seguir sozinha as fases em vez de depender de o
produtor lembrar de mexer no alvo a cada etapa.

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
