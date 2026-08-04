# Convenções do projeto

Regras que valem para qualquer um que mexa neste repositório. Existem porque
**cada uma já foi quebrada pelo menos uma vez**, e o estrago só apareceu depois.

## Git

- **Mensagens de commit em inglês**, no imperativo, descrevendo o *porquê* — não
  o *o quê*, que o diff já conta.
- **Nunca `git add .` nem `git add estufa_app`.** O Flutter regenera
  `estufa_app/{linux,macos,windows}/flutter/generated_*` a cada build, e esses
  arquivos **não entram em commit**. Estagie caminho por caminho
  (`git add estufa_app/lib docs/…`).
- **Nada de segredo versionado:** `.env`, `google-services.json` e a credencial
  do Firebase estão no `.gitignore` e devem continuar fora.
- Branch de trabalho: `test/http-local-device` — é dela que o Render publica.

## Build

**APK** — o `--dart-define` é obrigatório. Sem ele o app sobe com a nuvem
desconfigurada e **toda estufa aparece OFFLINE**, incluindo o simulador:

```
flutter build apk --release --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

**Firmware** — o `arduino-cli` não está no PATH; ele vem dentro da instalação da
IDE do Arduino:

```
"…/Arduino IDE/resources/app/lib/backend/resources/arduino-cli.exe" compile --fqbn esp32:esp32:esp32 firmware/sentinela_esp32
```

Saudável: ~86% do flash, ~15% da memória. Salto grande = alguma biblioteca
entrou sem querer.

**Testes** — servidor: `node --test "estufa_server/test/*.test.js"`.
App: `flutter test` dentro de `estufa_app`.

## Domínio (erros que parecem bug e não são)

- **Temperatura em Fahrenheit de propósito.** O produtor pensa em °F; converter
  para Celsius "para ficar certo" quebra a leitura dele.
- **Número de versão do firmware não sobe sozinho.** Reiniciou em `1.0` em
  04/08/2026 e só muda quando o produtor pede — ele diz *o que está na mão de
  alguém*, não *o que mudou no código*, que o `git log` já conta. Versões citadas
  em documentos antigos (`v1.16.0`, `v1.18.0`, `v1.24.0`…) são da numeração de
  bancada, listada em `HISTORICO_FIRMWARE.md`, e não existem mais como alvo de
  gravação.
- **Umidade nunca dispara alarme.** Só temperatura e fogo. Isso vale também na
  **aparência**: no relatório da estufada a umidade sai como `registro`, em
  cinza, e não com a marca vermelha de quem acionou alarme. Ela chegou a sair
  vermelha, no meio das linhas de "Alarme acionado", e a estufada parecia ter
  tido dezessete emergências que nunca existiram. Numa estufa de secagem a
  umidade ficar muito abaixo do ajuste é **o objetivo do processo**.
- **O aparelho é a fonte da verdade.** O app espelha o que ele reporta, não emite
  um segundo parecer.
- **O interruptor da sirene é sobre o ALARME**, não sobre todo som: apitos de
  confirmação tocam mesmo com ela desligada, e a notificação do celular é canal
  separado, com preferências próprias.

## Onde vai um arquivo novo

Convivem duas organizações no app, porque uma migração começou e parou:
`features/<assunto>/` e as pastas por camada na raiz (`screens/`, `services/`,
`widgets/`, `utils/`, `models/`). Sem destino declarado, cada um decide sozinho —
e já aconteceu: uma tela nova criou `features/home/screens/` porque a pasta não
existia, sem que isso fosse decisão de ninguém.

**O destino é `features/`.** Regra de bolso:

- **Tem dono claro?** (agendamento, notificações, monitoramento, aparelho, home,
  relatório) → `features/<assunto>/` — com `models/`, `screens/`, `services/`,
  `widgets/` dentro, conforme precisar.
- **Serve a todo mundo?** (`api_service`, `isar_service`, `monitor_estufas`, as
  entidades do Isar) → fica onde está, na raiz. É infraestrutura, não assunto.
- **Na dúvida entre dois assuntos**, escolha o que *usa*, não o que *parece*.

**Migração por oportunidade, nunca em bloco.** Mover arquivo em massa produz um
commit gigante que ninguém revisa e apaga o histórico de quem mexeu no quê. Ao
tocar num arquivo da raiz que tem dono claro, mova-o **no mesmo commit** se for
barato; se não for, deixe.

O que sobrou na raiz hoje (`screens/`, três widgets, `utils/`) é legado, não
modelo a seguir.

## Plataforma web — pendência com prazo

O app tem `web/`, desvios `kIsWeb` e **tres** pares `_web`/`_io`/`_stub`
(`isar_service`, `csv_exporter`, `browser_text_input`). Eram quatro; o de
`backup_file_service` saiu com o backup, em 04/08/2026.
O produto é Android; a web nunca foi usada em campo.

**Mantida por ora, sem decisão tomada** (01/08/2026): pode servir de
demonstração na banca. Enquanto durar, quem mexer nesses quatro assuntos precisa
lembrar que existe o outro lado.

**Decidir antes de começar a escrita do TCC.** Manter "por via das dúvidas" é
como dívida técnica costuma nascer, e cada desvio é um caminho a mais onde um
defeito se esconde.

## Arquivos gerados (`.g.dart`)

Os `.g.dart` do Isar são **versionados de propósito** — ~8.500 linhas, 38% do
app. Não é descuido: eles precisam estar em sincronia com os modelos, e já houve
incidente de código gerado desatualizado derrubando o app no boot
(`IsarError: Collection id is invalid`).

Portanto: **ao mexer numa entidade do Isar, regenere e commite junto.**

```
dart run build_runner build --delete-conflicting-outputs
```

Não confundir com os `generated_*` de `linux/macos/windows`, que o Flutter
regera a cada build e **não entram em commit**.

## Onde está o plano

- `AUDITORIA.md` — dívida técnica, com caixas de progresso. **É a fila de
  trabalho.**
- `HANDOFF.md` — estado geral e o que falta.
- `PLANO_POS_TESTES.md` — testes de campo e resultados.

Marque a caixa **no mesmo commit** da mudança. Documento que diz "feito" sobre
trabalho que não existe é pior que documento nenhum — já aconteceu aqui.

## Trabalho em partes

O projeto é grande demais para uma tacada só, e trabalho longo demais erra mais
perto do fim. Então:

- **Uma tarefa por vez**, ou em áreas que não se cruzam. Duas frentes na mesma
  tela dão conflito silencioso.
- **Quem escreve não verifica.** Conferir o próprio trabalho tende a acreditar em
  si mesmo; a conferência vale mais vinda de fora.
- **Mutação de teste se desfaz com cópia, nunca com `git checkout`.** Provar que
  um teste pega a regressão exige estragar o código de propósito — e desfazer
  isso com `git checkout -- arquivo` **apaga todo o trabalho não commitado
  daquele arquivo**, não só a estragadinha. Já aconteceu aqui, e custou a
  reconstrução de uma tela inteira. Copie antes, restaure da cópia.
- **Refatoração precisa de prova de que nada mudou** — inventário antes/depois,
  a suíte inteira, e um teste de fumaça que exercite o caminho real.
