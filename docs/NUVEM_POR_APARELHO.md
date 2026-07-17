# Nuvem por aparelho (status ao vivo multi-dispositivo)

Cada aparelho tem o **seu** estado ao vivo na nuvem. **Implementado** — este doc
registra o desenho. Resumo do que ficou pronto:

- **Servidor:** `GET /status?idHardware=X` devolve o estado daquele aparelho
  (mapa por `idHardware`, carga sob demanda do banco). O simulador segue sendo o
  aparelho `ESP32_REALISTIC_V2`, à parte dos reais. O `MODO_RECEPTOR` deixou de
  ser necessário (foi removido).
- **App:** `EstufaEntity.idHardware`, capturado na 1ª conexão local (do `/status`
  do ESP) e enviado ao ler a nuvem. Cada estufa puxa o seu.
- **Firmware:** id único por aparelho, gerado do MAC do chip.

Desenho original abaixo.

## O problema (hoje)

O `/status` ao vivo da nuvem serve **um único estado global** — o objeto em
memória do simulador (`statusFisico`). No modo receptor, esse objeto é
sobrescrito pela última leitura que chega via `POST /leitura`, **seja de qual
aparelho for**. Consequências:

- o simulador e o ESP real **sobrescrevem um ao outro**;
- a estufa cadastrada no app (que apontava para o simulador) passou a mostrar os
  dados do ESP real, porque ambos leem o mesmo `/status`;
- não dá para ter **várias estufas** com estados ao vivo distintos.

O **histórico já é por aparelho** (`leituras.dispositivo_id`, com
`leituras.fonte` e `dispositivos.identificador_hardware`); a `configuracoes`
também é por `dispositivo_id`. É só o `/status` **ao vivo** que é único.

## O objetivo

Cada aparelho é o **seu** na nuvem, identificado pelo `idHardware`. Cada estufa
no app puxa o estado do **seu** aparelho. Base necessária para múltiplas estufas.

## Desenho proposto

### Servidor

- Guardar a última leitura **por `idHardware`** (um mapa
  `idHardware -> { status, config, recebidoMs }`), atualizado a cada
  `POST /leitura` do aparelho correspondente.
- `GET /status?idHardware=X` devolve o estado **daquele** aparelho.
- Compatibilidade: `GET /status` sem parâmetro pode devolver o mais recente ou o
  aparelho padrão, para não quebrar clientes antigos.
- Persistir o mapa no boot a partir do banco (última leitura de cada
  `dispositivo_id`), para sobreviver a reinícios.
- O simulador passa a ser **apenas mais um aparelho** (ou é aposentado quando o
  modo receptor está ligado).

### App

- `EstufaEntity` ganha um campo **`idHardware`** (migração Isar).
- **Auto-captura:** ao conectar localmente, o `/status` do aparelho já traz o
  `idHardware`; o app guarda esse valor na estufa na primeira conexão local.
- Ao ler pela **nuvem**, o app manda `GET /status?idHardware=<o da estufa>` e
  também usa esse id no `GET /historico?idHardware=...` (já suportado).
- Enquanto uma estufa não tiver `idHardware` (cadastros antigos), usa o
  comportamento atual como fallback até a primeira conexão local capturá-lo.

### Migração / compatibilidade

- Estufas já cadastradas: `idHardware` vazio → captura na próxima conexão local.
- Servidor mantém o `/status` sem parâmetro funcionando durante a transição.

## Fases sugeridas

1. **Servidor multi-dispositivo:** mapa por `idHardware`, `/status?idHardware`,
   carga inicial do banco; `/status` sem parâmetro como fallback.
2. **App:** campo `idHardware` na `EstufaEntity`, auto-captura do `/status`
   local, envio do id ao ler a nuvem.
3. **Limpeza:** tratar o simulador como um aparelho nomeado; opcional separar
   claramente "estufa de teste" (simulador) de "estufa real".

## Relação com o resto

- Combina com a detecção de **"aparelho sem comunicação"** (staleness): cada
  aparelho terá o seu `recebidoMs`, então a staleness passa a ser por estufa.
- Não muda o contrato de leitura/comando por campo (LWW continua por
  `idHardware`).
