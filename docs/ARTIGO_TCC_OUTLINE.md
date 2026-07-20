# Esqueleto do artigo do TCC — Sentinela Smart

Estrutura sugerida para o artigo/monografia, com **o que entra em cada seção** e
**de onde puxar os fatos** (os `docs/` já versionados são a matéria-prima — não
inventar dados; tudo aqui tem lastro no código ou nos documentos).

> Como usar: escreva seção por seção. Em cada uma, a lista "Fontes" aponta o
> documento/arquivo com os fatos. Os "Fatos-chave" já trazem os números e
> decisões prontos, para não precisar recalcular. Reconciliar com a versão do
> artigo que você já começou (fora do repositório).

---

## Título e resumo

- **Título** (trabalho): *Sentinela Smart: uma arquitetura híbrida edge-first
  para monitoramento de estufas de cura de fumo em áreas rurais com internet
  instável.*
- **Resumo (PT) / Abstract (EN):** problema (monitorar a cura do fumo sem
  depender de internet), solução (app + aparelho + nuvem com fallback), método
  (protótipo com ESP32 e simulador), resultado (os três modos funcionando).
  ~150–250 palavras. Escrever por último.
- **Palavras-chave:** IoT; computação na borda (edge); offline-first;
  sincronização; cura de fumo; ESP32; Flutter.

---

## 1. Introdução

**Cobrir:** contexto da fumicultura no Sul do Brasil; a cura/secagem em estufa
como etapa crítica (um erro de temperatura estraga a estufada inteira);
realidade do produtor no interior — energia e internet instáveis; o gancho de
que soluções 100% em nuvem falham exatamente onde o produtor mais precisa.

- **1.1 Problema:** como monitorar e controlar a estufa de forma confiável
  quando a internet cai? Como não perder dados nem comandos numa queda?
- **1.2 Justificativa:** prejuízo de uma estufada perdida; segurança (risco de
  incêndio); o produtor precisa saber, mesmo dormindo/fora, se algo deu errado.
- **1.3 Objetivos:**
  - *Geral:* desenvolver um sistema híbrido de monitoramento que funcione na
    borda (sem depender da nuvem) e use a nuvem como histórico e acesso remoto.
  - *Específicos:* (a) app móvel de monitoramento/controle; (b) aparelho de
    campo (ESP32) + simulador equivalente; (c) sincronização resiliente a
    quedas; (d) histórico e relatório por estufada; (e) alertas de segurança.
- **1.4 Estrutura do trabalho.**

**Fatos-chave:** temperaturas em **Fahrenheit de propósito** (granularidade fina
e padrão da indústria de flue-curing — *não* justificar como limitação nem
sugerir Celsius). Fases da cura já modeladas no sistema: Amarelação →
Murchamento → Fixação da Cor → Secagem da Folha → Secagem do Talo.
**Fontes:** conversa/projeto; `logica.js` (tabela `cicloDeCura`).

---

## 2. Fundamentação teórica

**Cobrir (cada um com 2–4 parágrafos e referências):**

- **2.1 IoT e computação na borda (edge computing):** por que processar/decidir
  perto do dado; latência e disponibilidade; a borda como fonte da verdade.
- **2.2 Arquiteturas offline-first / edge-first:** o dispositivo local é
  autônomo; a nuvem é conveniência (histórico, acesso remoto), não dependência.
- **2.3 Sincronização de dados e resolução de conflitos:** filas offline;
  **Last-Write-Wins (LWW)** por campo com carimbo de tempo; idempotência.
- **2.4 Bancos locais x nuvem:** banco embarcado no celular (Isar) x banco
  relacional gerenciado (PostgreSQL/Supabase); política de retenção.
- **2.5 A cura do fumo (flue-curing):** as fases, o papel de temperatura e
  umidade, por que o controle térmico é crítico e sensível a erro.
- **2.6 Tecnologias:** Flutter/Dart; Node.js/Express; ESP32; Firebase Cloud
  Messaging (para o item de notificações).

**Fontes:** literatura externa (buscar referências) + `PLANO_BANCO_DADOS.md`
(retenção, LWW) + `NOTIFICACOES_PUSH.md` (FCM).

---

## 3. Metodologia / Materiais e métodos

**Cobrir:**

- **3.1 Tipo de pesquisa:** aplicada, desenvolvimento de protótipo
  (design science / pesquisa-desenvolvimento).
- **3.2 Materiais:** ESP32 + sensores (o aparelho real, em fase de chegada);
  simulador em Node como *ESP32 virtual* para desenvolver/testar sem o hardware;
  Render (deploy) + Supabase (Postgres, pooler IPv4); celular Android (APK).
- **3.3 Método de desenvolvimento:** incremental; controle de versão (Git);
  testes automatizados como rede de segurança para refatorações.
- **3.4 Etapas:** modelagem do domínio → app local → servidor/nuvem →
  sincronização → histórico/relatório → alertas → validação por cenários.

**Fatos-chave:** a mesma interface do app lê o ESP32 real e o virtual **sem
mudar código** (contrato de API conferido). Cobertura de testes: **11 no app,
62 no servidor** (atualizar o número ao escrever).
**Fontes:** `TESTE_ESP32_REAL.md`, `ESP32_VIRTUAL.md`, `CONTRATO_API.md`,
`EXECUCAO_LOCAL.md`, `CONFIGURACAO_ESP32.md`.

---

## 4. Desenvolvimento (a solução)

O capítulo central. Descrever a arquitetura e cada componente.

- **4.1 Visão geral da arquitetura híbrida:** diagrama com três papéis —
  **Aparelho** (borda, fonte da verdade), **App** (interface), **Nuvem**
  (histórico + acesso remoto/fallback). *Reaproveitar o diagrama e a tabela de
  componentes do `DEMO.md`.*
- **4.2 Os três modos de conexão:** `LOCAL → NUVEM → OFFLINE`, resolvidos
  automaticamente na ordem IP local → porta 80 → nuvem; indicador visível ao
  usuário.
- **4.3 Aparelho de campo (ESP32) e o ESP32 virtual:** função, o que mede, como
  empurra leituras (`POST /leitura`).
- **4.4 Aplicativo (Flutter):** monitoramento em tempo real; LEDs/estados;
  controle de ajustes; banco local Isar; tela de relatório por estufada.
- **4.5 Servidor e nuvem:** Node/Express; endpoints (`/status`, `/leitura`,
  `/historico`, `/sincronizar`); keep-alive contra o *sleep* do plano grátis.
- **4.6 Modelo de dados:** `dispositivos`, `configuracoes`, `leituras`,
  `comandos_sync`; entidades de estufada e eventos; rastreabilidade de origem
  (`simulador`/`hardware`/`manual`).
- **4.7 Política de armazenamento:** 1 leitura a cada **10 min** durante a
  estufada + gravação imediata de eventos relevantes; fora de estufada, não
  historiar; downsampling do gráfico para o relatório ficar legível.
- **4.8 Sincronização resiliente:** fila offline de comandos (app) e buffer de
  leituras (aparelho/servidor); **LWW por campo**; comando antigo é ignorado.
- **4.9 Lógica de segurança / alarmes:** tolerância de **±5 °F**; limite de
  incêndio **175 °F** (ou ajuste+5 se ajuste > 170); sensor de chama; a umidade
  **não** dispara sirene (decisão de projeto — produtor não a acompanha).
- **4.10 Relatório da estufada:** resumo, eventos, gráfico (degraus + linha de
  ajuste), exportação PDF/CSV; numeração sequencial das estufadas.
- **4.11 Alertas remotos (projetado):** arquitetura de push (FCM); watchdog de
  silêncio na nuvem; distinção "falta de luz × falta de internet" via aparelho
  com bateria + sensor de tensão; preferências por evento. *Deixar claro o que é
  implementado x planejado.*

**Fatos-chave (prontos para citar):**
- Ordem de resolução: `ApiService` tenta IP local → porta 80 → URL de nuvem.
- LWW por campo com timestamp; `POST /sincronizar` drena a fila.
- Buffer de leituras em JSONL (`.buffer_push.jsonl`), reenviado em ordem ao
  reconectar; descarta as mais antigas se estourar o limite.
- Retenção local (Isar): descarta leituras com mais de **10 meses**. A **nuvem**
  tem retenção equivalente (~**300 dias**, configurável por `CLOUD_RETENTION_DAYS`),
  executada no boot e a cada 24 h — some com a política de dedup (1 a cada
  10 min + eventos) para o banco não crescer sem limite.
- Deploy: Render (dorme após ~15 min de inatividade) + Supabase (Session pooler,
  IPv4).

**Fontes:** `DEMO.md`, `PLANO_BANCO_DADOS.md`, `CONTRATO_API.md`,
`SEGURANCA_COMANDOS.md`, `NOTIFICACOES_PUSH.md`, e o código
(`logica.js`, `api_service.dart`, `isar_service.dart`).

---

## 5. Testes e resultados

**Cobrir:** validação por **cenários** (mais convincente que "rodou"):

- **Cenário 1 — Local-first (Edge):** app lê o aparelho pela Wi-Fi, sem internet.
- **Cenário 2 — Fallback automático:** derruba o local, app cai para NUVEM; volta
  o local, reassume LOCAL.
- **Cenário 3 — Comando offline (fila + LWW):** ajuste feito offline não se
  perde; sincroniza ao reconectar.
- **Cenário 4 — Histórico + buffer de leituras:** leituras no Supabase; simula
  queda de internet; buffer reenvia em ordem ao voltar.
- **Build e implantação:** APK release em Android; observações do teste em campo
  (LED/alarme calibrados com feedback real).
- **Testes automatizados:** o que cobrem (máquina de estados de oscilação,
  rastreador de conexão, lógica de alarme).

**Fatos-chave:** os quatro cenários e as "falas-chave" já estão roteirizados no
`DEMO.md` — reaproveitar como evidência de resultado.
**Fontes:** `DEMO.md`, `TESTE_ESP32_REAL.md`.

---

## 6. Conclusão e trabalhos futuros

- **6.1 Conclusão:** os objetivos atingidos; o diferencial (funciona na borda,
  não depende da nuvem, resiliente a quedas de rede/energia).
- **6.2 Limitações honestas:** silêncio total (luz+internet) não é 100%
  distinguível sem hardware dedicado; push depende de nuvem sempre ligada
  (tier pago) e Firebase; validação em campo ainda inicial.
- **6.3 Trabalhos futuros:** ESP32 real em produção (bateria + sensor de tensão);
  notificações push por evento; exclusão/retenção de dados na nuvem; agendamento
  confiável no aparelho (ventoinha/temperatura). *Puxar de `HANDOFF.md`.*

**Fontes:** `HANDOFF.md` (pendências), `NOTIFICACOES_PUSH.md`.

---

## Referências

Levantar referências de: IoT e edge computing; arquiteturas offline-first;
sincronização/LWW; bancos embarcados; cura/secagem de fumo (flue-curing);
documentação oficial de Flutter, ESP32 e Firebase. (ABNT.)

---

## Lembretes ao escrever

- **Fahrenheit é decisão de projeto**, não limitação — nunca sugerir Celsius.
- Separar sempre **implementado** de **planejado** (principalmente as
  notificações push).
- Preferir descrever **decisões e trade-offs** (ex.: por que a umidade não
  dispara alarme; por que LWW; por que edge-first) — é o que dá densidade
  acadêmica.
- Números e nomes vêm dos `docs/` e do código; ao citar, conferir se ainda valem.
