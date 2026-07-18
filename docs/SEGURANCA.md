# Postura de segurança

O que o sistema protege, como, e quais riscos foram **aceitos conscientemente**
— com o porquê. Útil para a banca e para decidir o que endurecer depois.

## Modelo de ameaça (resumo)

O aparelho fica na rede Wi-Fi da propriedade, atrás de NAT — ninguém o alcança
de fora. A nuvem (Render) é pública na internet. Os dados são telemetria de
secagem e comandos de ajuste; o pior caso prático é um terceiro **ler** a
operação da estufa ou **mandar um ajuste** nela (ex.: mudar o alvo de
temperatura durante uma estufada).

## Proteções em vigor

| Camada | Proteção |
|---|---|
| Nuvem | **Todas** as rotas exigem o token quando configurado — leituras incluídas (`/status`, `/historico`) |
| Nuvem | Servidor **se recusa a subir** com token fraco/ausente (`token_policy.js`); exceção só com `PERMITIR_SEM_TOKEN=true` |
| Nuvem | Comparação de token **timing-safe** (`crypto.timingSafeEqual`) |
| Nuvem | SQL 100% parametrizado (sem injeção); payloads validados com faixas e lista fechada de campos; `idHardware` limitado a 64 caracteres |
| Nuvem | Erros internos não vazam ao cliente (detalhe só no log); CORS restringível via `ALLOWED_ORIGINS` |
| Aparelho | Comandos (`POST /sincronizar`) exigem o token; TLS ao falar com a nuvem |
| App | Chave enviada em toda chamada (`Authorization: Bearer` + `X-Device-Token`) |
| Repositório | `.env` (chaves, banco) fora do versionamento |

No aparelho, o `GET /status` **local** é aberto de propósito: a operação
edge-first na rede da propriedade depende dele, e o alcance é só quem já está
no Wi-Fi da fazenda.

## Riscos aceitos (e o porquê)

- **O ESP32 não valida o certificado da nuvem** (`setInsecure()`). Um atacante
  *no caminho* da conexão (roteador da fazenda ou provedor comprometidos)
  poderia se passar pela nuvem — inclusive injetando comandos na busca do
  `/comandos`. Fixar o CA raiz no firmware quebraria o acesso remoto de todos
  os aparelhos em campo a qualquer rotação de certificado do Render, e
  regravar firmware exige ir até a estufa. Com o alcance restrito a ataques
  on-path, o custo supera o risco **nesta escala**. Endurecimento futuro:
  embutir o CA com atualização OTA do firmware.
- **Token único compartilhado** entre app, aparelhos e nuvem. Um vazamento
  expõe tudo; tokens por aparelho seriam o próximo passo (a caixa de comandos
  por `idHardware` já deixa o terreno pronto).
- **O backup exportado contém as chaves de acesso** — necessário para o
  restore funcionar. O app avisa ao compartilhar; o arquivo deve ser tratado
  como senha.
- **Sem rate-limiting.** Com token forte (48+ caracteres) e comparação
  timing-safe, força bruta é impraticável; um limitador por IP atrás do proxy
  do Render arriscaria bloquear o próprio produtor (operadoras móveis
  compartilham IPs via CGNAT).
- **`rejectUnauthorized: false` na conexão com o banco** — exigência prática
  do pooler do Supabase; a conexão segue cifrada, sem validação da cadeia.

## Se um segredo vazar

1. Gerar token novo forte (`openssl rand -hex 24`);
2. Trocar `ESTUFA_API_TOKEN` no Render;
3. Trocar a "Chave de acesso" das estufas no app;
4. Regravar os aparelhos com o novo `DEVICE_TOKEN`;
5. Se o vazamento incluir o banco: trocar a senha no Supabase e atualizar
   `DATABASE_URL`.
