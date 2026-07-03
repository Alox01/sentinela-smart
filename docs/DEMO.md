# Roteiro de demonstração (arquitetura híbrida)

Guia prático para demonstrar o Sentinela Smart funcionando nos três modos:
local (Edge), nuvem (remoto) e offline (resiliência). O app já alterna sozinho
entre local e nuvem — este roteiro só orquestra os cenários.

## Componentes

| Papel | Onde roda | Função |
|---|---|---|
| **Nuvem** | Render — `https://estufa-server.onrender.com` | Histórico (Supabase) e acesso remoto/fallback |
| **Aparelho** | PC rodando `estufa_server` na mesma Wi-Fi | "ESP32 virtual": o app lê localmente e ele empurra leituras |
| **App** | Celular (APK) ou Chrome | Interface; alterna local ↔ nuvem automaticamente |

## Como o app decide (já implementado)

`ApiService._resolverBaseAtiva()` tenta, nesta ordem: **IP local → porta 80 →
URL de nuvem**. O indicador de conexão mostra `LOCAL`, `NUVEM` ou `OFFLINE`. A
URL de nuvem vem do build (`--dart-define=CLOUD_API_URL=...`); o token vem da
chave cadastrada em cada estufa.

## Preparação (antes de apresentar)

1. **Acorde a nuvem** (plano grátis dorme após ~15 min): abra
   `https://estufa-server.onrender.com/status` no navegador ~1 min antes.
2. **Descubra o IP do PC** na rede local:
   ```powershell
   ipconfig
   ```
   Anote o "Endereço IPv4" do Wi-Fi (ex.: `192.168.1.11`).
3. **Rode o aparelho** local (modo push já vem do `.env`):
   ```powershell
   node server.js
   ```
   Confirme no log: `Persistencia local desligada (modo aparelho)` e
   `ESP32 virtual: empurrando leituras para https://estufa-server.onrender.com`.
4. **Rode/instale o app** apontando a nuvem como fallback:
   ```powershell
   flutter run --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
   ```
   (ou `flutter build apk --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com`)
5. **Cadastre a estufa** no app:
   - Endereço/IP: `192.168.1.11:3000` (o IP do PC do passo 2)
   - Chave de acesso: `123456` (mesma do `ESTUFA_API_TOKEN`)

## Cenário 1 — Local-first (Edge)

- Com o aparelho rodando, abra a estufa no app.
- O indicador deve mostrar **LOCAL**: o app está lendo o aparelho pela Wi-Fi,
  sem passar pela internet.
- **Fala-chave:** "o monitoramento não depende da nuvem; funciona na borda".

## Cenário 2 — Fallback automático para a nuvem

- Pare o aparelho no PC (`Ctrl+C`) ou tire o PC da rede.
- Aguarde alguns segundos: o app deixa de achar o local e cai para **NUVEM**
  (lendo o Render). Pode levar ~4s (timeouts) ou mais se a nuvem tiver dormido.
- Ligue o aparelho de novo → o app volta para **LOCAL**.
- **Fala-chave:** "quando a rede local cai, o acesso remoto assume; quando volta,
  prioriza o local de novo".

## Cenário 3 — Comando offline (fila + Last-Write-Wins)

- Com o aparelho **parado**, mude o ajuste de temperatura no app.
- O comando não é perdido: entra na fila local (Isar) — veja o aviso
  "Comando enfileirado para sincronizacao posterior".
- Ligue o aparelho. Na próxima leitura, o app drena a fila via
  `POST /sincronizar`, aplicando LWW por campo (timestamp).
- **Fala-chave:** "ajustes feitos offline não se perdem; sincronizam ao voltar".

## Cenário 4 — Histórico na nuvem + buffer offline de leituras

- Com o aparelho em modo push, as leituras chegam ao Supabase. Mostre no
  **Supabase → Table editor → `leituras`** as linhas aparecendo (fonte
  `hardware`).
- Simule uma queda: desligue a internet do PC por ~1 min. No log do aparelho:
  `ESP32 virtual: leitura guardada no buffer local` (arquivo
  `.buffer_push.jsonl`).
- Religue a internet. No log: `ESP32 virtual: buffer reenviado (N leitura(s))`,
  e as linhas atrasadas aparecem no Supabase.
- **Fala-chave:** "nenhuma leitura é perdida durante a queda; sobem em ordem ao
  reconectar".

## Dica de arquitetura para a banca

Opcional, para deixar a nuvem como receptor "puro" (sem gerar dados do próprio
simulador), defina no Render a variável `PERSISTIR_LOCAL=false`. Aí o único
gerador de histórico passa a ser o aparelho que empurra via `POST /leitura`.
