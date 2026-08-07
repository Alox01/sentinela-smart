# Mapa do código — o que responde o quê

Feito para a apresentação do TCC. A banca pode perguntar "qual biblioteca você
usou para o gráfico?", "onde está a lógica do alarme?", "como o app funciona sem
internet?". São perguntas de quem quer confirmar que você conhece o próprio
sistema — e todas têm resposta de uma frase.

Leia isto uma vez antes de apresentar. Não é documentação técnica; é o que
responder.

## As três partes, em uma frase cada

- **Firmware (ESP32, C++/Arduino)** — decide sozinho. Lê os sensores, aciona o
  alarme e obedece aos botões **sem depender de rede nenhuma**.
- **App (Flutter/Dart, Android)** — espelha o que o aparelho reporta e envia
  comandos. Guarda tudo localmente para funcionar offline.
- **Servidor (Node.js/Express + PostgreSQL)** — guarda o histórico e leva comando
  ao aparelho quando o celular está longe da propriedade.

## Bibliotecas, e por que cada uma

### App

| Biblioteca | Para quê | Por que essa |
|---|---|---|
| `isar` | banco local no celular | banco NoSQL embutido, rápido, funciona sem internet — é o que sustenta o modo offline |
| `http` | falar com aparelho e nuvem | o protocolo é HTTP simples; não havia motivo para algo maior |
| `fl_chart` | gráfico da estufada | desenha linha e pontos com escala controlada, e permite ler os valores desenhados (foi como um gráfico vazio foi detectado por teste) |
| `pdf` + `printing` | exportar o relatório | gerar e compartilhar o PDF da estufada |
| `firebase_messaging` | notificação push | alerta chega com o app fechado, que é o caso que importa às 3h da manhã |
| `flutter_local_notifications` | mostrar o aviso e agendar | canais de som por assunto, e o alarme agendado toca sem internet |
| `shared_preferences` | preferências simples | interruptores e silenciamentos, que não merecem uma tabela |
| `qr_flutter` + `app_links` | QR e link do convite | compartilhar acesso pela câmera comum do outro celular |
| `timezone` | agendamento correto | alarme às 3h tem de ser 3h locais, com horário de verão resolvido |
| `intl` | datas e números em português | — |

### Servidor

| Biblioteca | Para quê |
|---|---|
| `express` | rotas HTTP |
| `pg` | PostgreSQL (Supabase) |
| `firebase-admin` | disparar o push |
| `helmet` | cabeçalhos de segurança |
| `express-rate-limit` | limite de 180 requisições/min |
| `cors` | acesso do app |

### Firmware

`DHT sensor library` (sensor de temperatura/umidade), `TM1637Display` (visor de 4
dígitos), `ArduinoJson` (montar e ler JSON), `Preferences` (NVS — memória que
sobrevive à queda de energia), `WiFi`/`WebServer`/`ESPmDNS` (rede e nome local).

## Onde está cada coisa

### "Onde está a lógica do alarme?"

**No firmware**, em `atualizarSaidas()` — é o único lugar que decide se a sirene
toca. Fogo toca **contínuo**; temperatura fora da faixa toca **intermitente**;
quem está na estufa distingue os dois pelo som.

O limite de incêndio está em `limiteFogoF()`: **175 °F**, ou **ajuste + 5** quando
o ajuste passa de 170 — porque existe cura que trabalha acima disso, e 175 fixo
acusaria incêndio com a estufa fazendo o que foi mandada fazer.

A mesma regra existe em três lugares (firmware, `logica.js` no servidor e
`limiar_incendio.dart` no app) porque são três linguagens e **o aparelho tem de
decidir sozinho, sem rede**. Já divergiram uma vez, e por isso hoje há teste.

### "Como funciona sem internet?"

Três camadas, e é o coração do trabalho:

1. **O aparelho não precisa de ninguém.** Sensor, alarme e botões são locais.
2. **O app fala direto com o aparelho** pela rede local (`sentinela-xxxxxx.local`,
   mDNS), sem passar pela nuvem.
3. **Comando dado offline entra numa fila** (`pendencias`) e sai quando a conexão
   volta.

A tela mostra em qual dos quatro estados está: `LOCAL`, `NUVEM`, `SEM SINAL`,
`OFFLINE`.

### "E se o celular e a nuvem discordarem?"

**Last-Write-Wins por campo**, com carimbo de tempo em cada um. Quem escreveu por
último vence — campo a campo, não o registro inteiro. Está em `sync.js` no
servidor e no `/sincronizar` do firmware.

### "Como o aparelho é configurado sem computador?"

Segurar os **três botões por 3 segundos** abre um ponto de acesso
(`Sentinela-Config`). O celular conecta nele e configura a rede pelo app. Está em
`verificarModoConfig()` e `handleConfigSalvar()`.

### "Como funciona a autenticação?"

Comandar exige uma chave. Ela é **gerada pelo próprio aparelho** e nunca é
digitada por ninguém. Para obtê-la, o celular precisa estar fisicamente na frente
do aparelho: três botões e o **PIN de 4 dígitos do visor**.

Os 4 dígitos bastam por três motivos, todos no firmware: **sorteado a cada
entrada**, **morre em 5 erros**, e **só existe no modo de configuração**, que
expira sozinho.

### "Onde ficam os dados?"

- **No celular:** Isar — estufas, leituras, estufadas, eventos e a fila de
  comandos pendentes.
- **Na nuvem:** PostgreSQL (Supabase) — histórico com retenção, estado por
  aparelho, agendamentos e inscrições de push.
- **No aparelho:** NVS — rede, chave e ajustes, para sobreviver à queda de
  energia.

### "Como você testou?"

- **App:** 153 testes (`flutter test`).
- **Servidor:** 213 testes (`node --test`).
- **Firmware:** compilação real no CI a cada push, com o core esp32 3.2.0.
- **Campo:** registrado em `PLANO_POS_TESTES.md`, com o que falhou e o que foi
  corrigido.

## A pergunta difícil, e a resposta honesta

**"Como você garante que está seguro?"**

Não está, no sentido absoluto — e o texto declara três limites conscientes
(`SEGURANCA.md`): o aparelho não valida o certificado da nuvem; a chave global
ainda autoriza aparelho que não registrou a sua; não há registro de auditoria.
Cada um está escrito com o motivo de ter ficado assim e como seria a correção.

O risco aqui é **operacional, não de dados pessoais**: o sistema não guarda dado
de pessoa nenhuma. O que se protege é o controle da estufa.

Declarar o limite é mais forte que afirmar uma segurança que não se sustenta.
