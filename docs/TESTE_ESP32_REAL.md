# Teste com o ESP32 real

O app já está pronto para ler e controlar o ESP32 real **na rede local** — o
contrato foi conferido e bate com o firmware (`firmware/sentinela_esp32`):
`GET /status` retorna `{"status": {...}, "config": {...}}` com os mesmos campos
que o app espera, e `POST /sincronizar` aplica o ajuste de temperatura (o ESP32
ignora a umidade, pois nao tem atuador de umidade). **Nenhuma mudanca de codigo
e necessaria para o teste local.**

## Checklist (quando o aparelho chegar)

1. No firmware (`sentinela_esp32.ino`), preencher no topo: `ssid`, `senha` do
   Wi-Fi e `chaveAcesso`. Gravar no ESP32.
2. Abrir o monitor serial e anotar o **nome local** e o **IP** que o ESP32
   mostra, por exemplo `sentinela-a1b2c3.local` e `192.168.1.21`.
3. No app, cadastrar a estufa:
   - Endereço preferencial: `<NOME_LOCAL>.local`, sem `http://` e sem porta.
   - Alternativa: `<IP_DO_ESP32>:80` (o ESP32 serve na porta **80**, não 3000).
   - Chave de acesso: a mesma `chaveAcesso` do firmware.
4. Celular e ESP32 na **mesma Wi-Fi**. O app deve indicar **LOCAL**, mostrar a
   temperatura/umidade reais e permitir controlar a temperatura pelos botoes.

Isso valida o nucleo da tese: app lendo/controlando o aparelho fisico na rede
local, funcionando sem depender da nuvem.

O nome `.local` depende de mDNS e funciona apenas na mesma rede. Se o celular ou
o roteador não resolver o nome, use o IP mostrado no Monitor Serial.

## Fase 2 — historico na nuvem com o ESP32 (fazer com o aparelho em maos)

O ESP32 real usa `idHardware` = `ESP32_PROTOTYPE_01` e o firmware atual so serve
dados (nao faz `POST /leitura`). Para ter historico na nuvem tambem, a opcao
escolhida foi a **(A) app como ponte**: quando o app le o ESP32 localmente, ele
tambem empurra a leitura para a nuvem (`POST /leitura`) com o `idHardware` do
aparelho, e passa a consultar `/historico` por esse id. Nao exige mexer no
firmware; a limitacao e que so grava enquanto o app esta aberto. Implementar
quando o aparelho estiver disponivel para testar de verdade.
