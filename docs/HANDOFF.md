# Handoff / estado do projeto

Ponto de retomada para continuar o trabalho em qualquer máquina (o histórico do
chat fica local; este arquivo e o Git são a memória portátil do projeto).

## Repositório oficial

`https://github.com/Alox01/sentinela-smart` — branch de trabalho:
`test/http-local-device`. Regras de versionamento em uso: commits/branches em
inglês, sem menção a ferramentas de IA, `main` = produção, não usar
`git add .` cego (o Flutter gera arquivos que aparecem como modificados).

## O que já funciona

- App Flutter (Android/APK) com monitoramento em tempo real, arquitetura
  híbrida local↔nuvem↔offline (indicador LOCAL/NUVEM/OFFLINE automático).
- Sincronização LWW por campo; fila offline de comandos (app) e buffers de
  leitura (servidor e ESP32 virtual).
- Servidor Node deployado na nuvem (Render + Supabase), com `GET /historico`,
  `POST /leitura`, keep-alive, e o ESP32 virtual (push HTTP).
- Relatório com resumo, gráfico (degraus + linha de ajuste + amostragem 10min/
  eventos com cooldown), eventos e histórico preenchido pela nuvem.
- Guias: `docs/ARQUITETURA*`, `CONTRATO_API.md`, `DEMO.md`, `ESP32_VIRTUAL.md`,
  `SEGURANCA_COMANDOS.md`, `ROADMAP_PRE_APK.md`.

## Pendências

1. **Relatório em PDF — concluído.** O botão de download da
   `historico_screen.dart` virou um menu **PDF / CSV**. O PDF
   (`relatorio_pdf_service.dart`) traz cabeçalho, resumo, gráficos de
   temperatura/umidade, eventos e tabela de leituras, e é compartilhado via
   `Printing.sharePdf` (share sheet: WhatsApp, imprimir, salvar). CSV mantido.

2. **Observar o teste da nuvem.** Confirmar que, ao fechar o app e reabrir o
   relatório, o histórico gravado pela nuvem preenche os "buracos".

3. **Teste com o ESP32 real (aguardando o aparelho).** O app já lê/controla o
   ESP32 na rede local sem mudança de código (contrato conferido). Checklist e a
   fase 2 (histórico na nuvem via app-ponte) em `docs/TESTE_ESP32_REAL.md`.
   Implementar a fase 2 quando o aparelho chegar.

4. **Revisão geral do código (solicitada).** Passar o projeto inteiro buscando
   melhorias viáveis sem alterar comportamento: quebrar arquivos grandes
   (`monitoramento_screen.dart`, `isar_service.dart`), simplificações, remoção
   de código morto, consistência. Fazer em passos pequenos e testáveis.

## Build do APK (lembrete)

Sempre **release** (bug do Isar 3.1.0 em debug). Ver `memory`/gotchas:

```
flutter build apk --release --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

## Continuar em outra máquina

O histórico desta conversa fica na máquina atual. Para retomar em outro PC:
clonar o repositório acima, abrir o Claude Code na pasta e pedir para ele ler
`docs/` (começando por este arquivo). Todo o contexto de arquitetura e as
pendências estão versionados aqui.
