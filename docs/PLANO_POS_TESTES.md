# Plano depois dos testes de campo

> Escrito em 25/07/2026, com o app e o servidor no ar e o firmware 1.13.0
> compilado mas **ainda não gravado**. A ordem abaixo pressupõe que os testes de
> campo aconteçam primeiro — vários itens só fazem sentido depois deles.

## Por que testar antes de continuar

Muita coisa foi escrita nos últimos dias e **nada disso rodou em hardware**:
o ESP está com a 1.9.0 enquanto o repositório tem a 1.13.0 (quatro versões de
diferença), as notificações ganharam canais e semântica novos, e o agendamento
inteiro nasceu agora. É o maior risco atual do projeto: código correto no papel
e não provado.

Nenhum item deste plano é grande. O que muda tudo é o resultado dos testes.

## 1. Testes de campo (só o produtor pode fazer)

| Teste | O que prova | Depende de |
|---|---|---|
| Gravar a **1.13.0** | destrava os quatro seguintes | — |
| Segurar o botão do buzzer 3 s | liga/desliga a sirene sem celular (2 apitos × 1 longo) | 1.13.0 |
| Modo de configuração num celular real | portal cativo e IP fixo, **nunca abertos fora do código** | 1.13.0 |
| Queda de energia | o ajuste volta da NVS, e o watchdog avisa | 1.13.0 |
| Alarme de madrugada | volume de alarme e "Não perturbe" — celular no silencioso, app fechado | APK novo |
| Agendar e fechar o app | lembrete chega **e** o ajuste muda sozinho | APK + servidor |
| Ponte de leitura | energia sim, internet da propriedade não, celular no 4G → **sem** falso "sem comunicação" | APK |

**O que anotar em cada um:** o que aconteceu, quanto tempo levou e se o app
estava aberto ou fechado. Esses números viram a seção de resultados do TCC — e,
se algo falhar, são eles que dizem se o problema é canal, permissão ou
preferência.

## 2. Correções do que os testes acharem

Deixado em branco de propósito. É a razão de os itens abaixo não estarem
agendados: qualquer falha em campo tem prioridade sobre funcionalidade nova.

Dois pontos já conhecidos, que os testes podem confirmar ou derrubar:

- **Acomodação de 5 min pode ser curta** para fornalha lenta: se o alarme de
  temperatura baixa disparar sempre depois de um ajuste para cima, o valor
  precisa subir (`TEMPO_ACOMODACAO_MS`).
- **Os alarmes usam a mesma sirene.** Incêndio, temperatura muito elevada,
  temperatura fora da faixa e sem comunicação soam parecidos. Se na prática
  confundir, o caminho é um segundo arquivo de áudio — separando "vá ver" de
  "corra".

## 3. Decisão do limiar de incêndio

Pendente há tempo, e é **conhecimento do produtor**, não do software: os 175 °F
com máxima de trabalho em 165 °F deixam 10 °F de folga, com o sensor no ar mais
quente da estufa. Subir o limiar, ou trocá-lo por **velocidade de subida**?
Ver `AMBIENTE_ESTUFA.md` §3. Uma estufada completa observada responde isso.

## 4. Provisionamento, Parte 1 (pequeno)

Botão **"Cadastrar esta estufa"** na tela de sucesso da configuração, abrindo o
formulário já preenchido com o nome mDNS. Metade já existe — a tela lê e mostra
o nome. Melhora a primeira experiência, que hoje exige digitar um endereço que o
produtor acabou de ver na tela ao lado. Ver `CONFIGURACAO_ESP32.md`.

## 5. Escrita do TCC

O prazo que o produtor definiu era começar por volta de 08/08/2026. Os quatro
objetivos específicos estão implementados; o que falta para a escrita são os
**números dos testes** do item 1.

## Fora deste plano (trabalho futuro declarado)

- **Provisionamento Parte 2** — chave gerada pelo aparelho, TOFU. Muda o servidor
  de chave global para chave por aparelho: grande, e não bloqueia o TCC.
- **Curva de cura por fases** — ver `AGENDAMENTO_CURA.md`.
- MQTT, HTTPS no ESP, atuadores/relé, APK assinado para a Play Store.
