// Vigia o silencio dos aparelhos: se uma estufa para de reportar, ninguem
// consegue avisar por ela - o proprio aparelho e que morreu. Entao quem avisa e
// a nuvem, pela ausencia.
//
// Este e o caso mais provavel de queda de energia: o ESP32 nao tem bateria para
// mandar "estou sem luz" antes de desligar. O silencio e ambiguo por natureza
// (falta de luz ou falta de internet dao no mesmo), e a mensagem assume isso em
// vez de fingir certeza.

// 5 pushes perdidos (o aparelho reporta a cada 60s). Nao da para descer muito
// mais: um roteador reiniciando ou uma reconexao de Wi-Fi levam 1-2 min, e o
// aviso viraria alarme falso. Com a verificacao de 1 em 1 min, o produtor sabe
// em 5-6 min.
const LIMITE_SILENCIO_PADRAO_MS = 5 * 60 * 1000;
const INTERVALO_VERIFICACAO_PADRAO_MS = 60 * 1000;

// Validade dos avisos de comunicacao. Sao avisos de ESTADO: valem enquanto o
// estado vale. Se o celular estava sem internet e o problema ja passou, entregar
// na reconexao so assusta - o produtor recebe o alarme junto com o desmentido.
// 30 min cobre quem ficou um tempo sem sinal e ainda precisa saber, sem
// ressuscitar um susto de ontem. O aviso de incendio NAO usa validade.
const VALIDADE_AVISO_COMUNICACAO_MS = 30 * 60 * 1000;

/// Decide o que avisar sobre um aparelho. Puro: sem relogio, sem rede.
/// Devolve 'silencio' na entrada do silencio, 'retorno' quando volta a
/// reportar, e null quando nada mudou (para nao repetir aviso a cada rodada).
function decidirAviso({
  ultimoContatoMs,
  agoraMs,
  limiteMs = LIMITE_SILENCIO_PADRAO_MS,
  estavaSilencioso = false,
}) {
  // Aparelho sem nenhuma leitura conhecida: nao da para afirmar que ficou em
  // silencio (pode nunca ter sido ligado). Melhor calar do que alarmar a toa.
  if (!Number.isFinite(ultimoContatoMs) || ultimoContatoMs <= 0) return null;

  const silenciosoAgora = agoraMs - ultimoContatoMs > limiteMs;

  if (silenciosoAgora && !estavaSilencioso) return 'silencio';
  if (!silenciosoAgora && estavaSilencioso) return 'retorno';
  return null;
}

function formatarTempo(ms) {
  const minutos = Math.floor(ms / 60000);
  if (minutos < 60) return `${minutos} min`;
  const horas = Math.floor(minutos / 60);
  const resto = minutos % 60;
  return resto === 0 ? `${horas}h` : `${horas}h ${resto}min`;
}

function iniciarWatchdog({
  listarAparelhos,
  notificar,
  intervaloMs = INTERVALO_VERIFICACAO_PADRAO_MS,
  limiteMs = LIMITE_SILENCIO_PADRAO_MS,
  setIntervalFn = setInterval,
  agora = () => Date.now(),
  logger = console,
}) {
  if (typeof listarAparelhos !== 'function' || typeof notificar !== 'function') {
    return null;
  }

  // Quem ja foi avisado, para o aviso sair na borda e nao a cada rodada.
  const silenciosos = new Set();

  const verificar = async () => {
    try {
      const aparelhos = await listarAparelhos();
      const agoraMs = agora();

      for (const { idHardware, ultimoContatoMs } of aparelhos ?? []) {
        if (!idHardware) continue;
        const decisao = decidirAviso({
          ultimoContatoMs,
          agoraMs,
          limiteMs,
          estavaSilencioso: silenciosos.has(idHardware),
        });
        if (!decisao) continue;

        if (decisao === 'silencio') {
          silenciosos.add(idHardware);
          const desde = formatarTempo(agoraMs - ultimoContatoMs);
          await notificar({
            idHardware,
            evento: 'semComunicacao',
            titulo: 'Estufa sem comunicação',
            // Honesto sobre a duvida: melhor um "va conferir" a toa do que
            // perder a estufada por achar que estava tudo bem.
            corpo:
              `Parei de receber dados há ${desde}. Pode ser falta de energia ` +
              'ou de internet no local. Verifique.',
            critico: true,
            validadeMs: VALIDADE_AVISO_COMUNICACAO_MS,
          });
        } else {
          silenciosos.delete(idHardware);
          await notificar({
            idHardware,
            evento: 'semComunicacao',
            titulo: 'Estufa voltou a se comunicar',
            corpo: 'A comunicação com a estufa foi restabelecida.',
            critico: false,
            validadeMs: VALIDADE_AVISO_COMUNICACAO_MS,
          });
        }
      }
    } catch (erro) {
      // Vigia que derruba o servidor nao vigia nada.
      logger.error?.('Falha no watchdog de silencio:', erro.message);
    }
  };

  const timer = setIntervalFn(verificar, intervaloMs);
  timer?.unref?.();
  return { timer, verificar };
}

module.exports = {
  INTERVALO_VERIFICACAO_PADRAO_MS,
  LIMITE_SILENCIO_PADRAO_MS,
  decidirAviso,
  iniciarWatchdog,
};
