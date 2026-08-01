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
- **Umidade nunca dispara alarme.** Só temperatura e fogo.
- **O aparelho é a fonte da verdade.** O app espelha o que ele reporta, não emite
  um segundo parecer.
- **O interruptor da sirene é sobre o ALARME**, não sobre todo som: apitos de
  confirmação tocam mesmo com ela desligada, e a notificação do celular é canal
  separado, com preferências próprias.

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
- **Refatoração precisa de prova de que nada mudou** — inventário antes/depois,
  a suíte inteira, e um teste de fumaça que exercite o caminho real.
