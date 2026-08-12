# Sentinela Smart

Monitoramento e controle de estufas de secagem de fumo. O aparelho mede, alarma e
obedece aos botões sem depender de rede; o celular acompanha de perto ou de
longe.

A cura do fumo leva dias e não pode parar. A temperatura sai da faixa de
madrugada, e quem percebe tarde tira da estufa um fumo de qualidade pior, que
vale menos na hora de vender. Perder a estufada inteira é raro, mas acontece:
umidade demais cozinha o fumo, e incêndio no fim do ciclo não perdoa. O sistema
existe para que o produtor não precise levantar de hora em hora para conferir —
esteja ele dormindo perto da estufa ou em casa.

Quem decide a curva de secagem é o produtor. O aparelho não escolhe temperatura:
ele executa o ajuste que recebeu, e faz isso sozinho quando a rede cai.

**Trabalho de Conclusão de Curso.** O sistema roda em uma propriedade real; os
testes de campo estão registrados em [`docs/PLANO_POS_TESTES.md`](docs/PLANO_POS_TESTES.md),
com o que falhou e o que foi corrigido.

> **Temperaturas em Fahrenheit, de propósito.** É a unidade dos termômetros e das
> tabelas de cura usadas na região. Não é bug.

---

## 1. O que o sistema faz

- **Monitora** temperatura e umidade da estufa, com leitura contínua no visor do
  próprio aparelho.
- **Controla** o ajuste de temperatura pelos botões do aparelho ou pelo celular.
- **Alarma** por sirene: contínua para fogo, intermitente para temperatura fora
  da faixa. Quem está na estufa distingue os dois pelo som.
- **Sincroniza** aparelho, celular e nuvem, resolvendo divergência campo a campo.
- **Registra** a estufada — a curva completa da secagem, exportável em PDF e CSV.
- **Avisa** no celular por notificação push, mesmo com o aplicativo fechado.

A umidade é medida e registrada, mas **não dispara alarme**: a estufa não tem
atuador de umidade, e um alarme sem ação possível só ensina o produtor a ignorar
a sirene.

---

## 2. Arquitetura

O sistema é híbrido e **prioriza a borda**: o aparelho é a fonte da verdade, e a
nuvem é histórico, alcance remoto e push.

```
┌──────────────┐   Wi-Fi local (HTTP)   ┌──────────────┐
│   ESP32      │◄──────────────────────►│   Celular    │
│  (aparelho)  │   sentinela-xxxxxx     │    (app)     │
│              │        .local          │              │
│  sensores    │                        │  banco Isar  │
│  sirene      │                        │  fila de     │
│  botões      │                        │  pendências  │
│  visor       │                        └──────┬───────┘
└──────┬───────┘                               │
       │ POST /leitura                         │ HTTPS
       │                                       │
       ▼                                       ▼
   ┌───────────────────────────────────────────────┐
   │        Servidor Node.js (Render)              │
   │        PostgreSQL (Supabase) · push FCM       │
   └───────────────────────────────────────────────┘
```

Três garantias sustentam o desenho:

1. **O aparelho não depende de ninguém.** Sensor, alarme e botões funcionam sem
   rede alguma. Internet caiu, roteador morreu, celular sem bateria — a estufa
   continua protegida.
2. **O app fala direto com o aparelho** quando está na propriedade, pela rede
   local via mDNS, sem passar pela nuvem.
3. **Comando dado sem conexão entra numa fila** e sai quando a conexão volta.

Quando app e nuvem discordam, vale **Last-Write-Wins por campo**: cada campo tem
seu próprio carimbo de tempo, e quem escreveu por último vence — campo a campo,
não o registro inteiro.

Os diagramas (entidade-relacionamento, arquitetura, sequência e modelo local)
estão em [`docs/DIAGRAMAS.md`](docs/DIAGRAMAS.md).

---

## 3. Tecnologias

| Camada | Stack |
|---|---|
| Aparelho | ESP32 (Arduino core 3.2.0), C++ — DHT, TM1637, ArduinoJson, Preferences (NVS), WebServer, ESPmDNS |
| Aplicativo | Flutter/Dart (Android e iOS) — Isar, http, fl_chart, firebase_messaging, flutter_local_notifications, pdf/printing |
| Servidor | Node.js 22 + Express 5 — pg, firebase-admin, helmet, express-rate-limit |
| Banco | PostgreSQL (Supabase) na nuvem; Isar no celular; NVS no aparelho |
| Hospedagem | Render (servidor), Supabase (banco), Firebase Cloud Messaging (push) |

O porquê de cada biblioteca está em [`docs/MAPA_DO_CODIGO.md`](docs/MAPA_DO_CODIGO.md).

---

## 4. Estrutura do repositório

```
estufa_app/       aplicativo Flutter
estufa_server/    servidor Node.js/Express
firmware/         sketch do ESP32
database/         esquema do PostgreSQL
docs/             documentação técnica (índice em docs/README.md)
.github/          CI: testes do servidor e do app + compilação real do firmware
```

---

## 5. Como executar

### Servidor

```bash
cd estufa_server && npm ci && cp .env.example .env && npm start
```

Preencha o `.env`: `DATABASE_URL` (PostgreSQL), `ESTUFA_API_TOKEN` (chave dos
comandos) e `PORT`. Todas as variáveis estão comentadas no
[`.env.example`](estufa_server/.env.example). **O `.env` real nunca vai para o
Git.**

### Aplicativo

O `--dart-define` com a URL da nuvem é **obrigatório**. Sem ele o aplicativo sobe
sem nuvem configurada e tudo aparece como OFFLINE.

```bash
cd estufa_app && flutter pub get && flutter build apk --release --split-per-abi --dart-define=CLOUD_API_URL=https://SEU-SERVIDOR
```

O build de release é o que importa: o Isar tem um defeito conhecido no modo
debug. Para iOS, veja [`docs/IOS.md`](docs/IOS.md).

### Firmware

Abra `firmware/sentinela_esp32/sentinela_esp32.ino` na Arduino IDE com o core
**esp32 3.2.0** e as bibliotecas listadas no
[`.github/workflows/ci.yml`](.github/workflows/ci.yml). Pinagem e primeira
configuração em [`docs/CONFIGURACAO_ESP32.md`](docs/CONFIGURACAO_ESP32.md).

---

## 6. Local e remoto

O aplicativo mostra em qual dos quatro estados está, e o estado é honesto:

| Estado | Significa |
|---|---|
| `LOCAL` | falando direto com o aparelho pela rede da propriedade |
| `NUVEM` | fora da propriedade; leitura e comando passam pelo servidor |
| `SEM SINAL` | o aparelho parou de reportar à nuvem |
| `OFFLINE` | o celular está sem conexão; comandos entram na fila |

O aparelho é encontrado na rede local por mDNS, como `sentinela-xxxxxx.local`,
sem precisar descobrir endereço IP.

---

## 7. Segurança

Comandar a estufa exige uma chave. Ela é **gerada pelo próprio aparelho** e nunca
é digitada por ninguém — o produtor jamais a vê. Para obtê-la, o celular precisa
estar **fisicamente na frente do aparelho**:

1. segurar os três botões por 3 segundos, o que abre o ponto de acesso
   `Sentinela-Config`;
2. digitar no aplicativo o **PIN de 4 dígitos que aparece no visor**.

Quatro dígitos bastam porque o PIN é **sorteado a cada entrada**, **morre depois
de 5 erros** e **só existe durante o modo de configuração**, que expira sozinho.
A regra que o sistema defende é simples: *para comandar, é preciso ter estado na
frente do aparelho*.

O mesmo caminho serve para **tirar o acesso de outros celulares** — quando o
aparelho troca de dono, por exemplo. Quem está na frente dele gera uma chave nova,
e as antigas deixam de valer na mesma hora.

Os limites conscientes estão declarados em
[`docs/SEGURANCA.md`](docs/SEGURANCA.md), com o motivo de cada um e como seria a
correção. O risco aqui é operacional, não de dados pessoais: **o sistema não
guarda dado de pessoa nenhuma.**

---

## 8. Testes

```bash
cd estufa_server && npm test        # 213 testes
cd estufa_app && flutter test       # 153 testes
```

A cada push, o CI roda os dois conjuntos, a análise estática do app e uma
**compilação real do firmware** com o core esp32 3.2.0.

Os testes de campo — o que foi verificado com o aparelho ligado na estufa — estão
em [`docs/PLANO_POS_TESTES.md`](docs/PLANO_POS_TESTES.md). Registram tanto o que
funcionou quanto o que quebrou, porque a falha em campo é que produziu boa parte
das correções.

---

## 9. Limitações e trabalhos futuros

O que **não** está pronto, dito sem rodeio:

- O aparelho não valida o certificado da nuvem.
- Não há registro de auditoria de quem comandou o quê.
- Um sensor por estufa: o valor lido é de um ponto, não a média do volume.
- Sem atuação sobre a umidade, apenas leitura.
- Sem supressão automática de incêndio — o sistema alarma, não apaga
  ([`docs/SUPRESSAO_INCENDIO.md`](docs/SUPRESSAO_INCENDIO.md)).

Estudado e não construído: rádio LoRa para alcançar estufas sem Wi-Fi
([`docs/HUB_LORA.md`](docs/HUB_LORA.md)) e agendamento de curva de cura
([`docs/AGENDAMENTO_CURA.md`](docs/AGENDAMENTO_CURA.md)).

---

## Marca de build

O aplicativo tem um interruptor de compilação, `ESCOPO_TCC`, que reduz a
interface ao escopo declarado na proposta do trabalho — sai o compartilhamento de
acesso por QR Code, sai o agendamento de ajuste. O motivo de cada exclusão está
comentado em [`estufa_app/lib/escopo.dart`](estufa_app/lib/escopo.dart).

```bash
flutter build apk --release --split-per-abi --dart-define=ESCOPO_TCC=true --dart-define=CLOUD_API_URL=https://SEU-SERVIDOR
```
