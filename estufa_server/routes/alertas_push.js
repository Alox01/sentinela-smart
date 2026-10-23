const { iniciarWatchdog } = require('../watchdog');
const { log } = require('../log');
const { ID_SIMULADOR } = require('./estado_estufa');

// Intervalos de repetição enquanto a condição crítica permanecer ativa.
// Incêndio e superaquecimento exigem resposta imediata; desvios comuns aguardam
// o tempo previsto para a intervenção e a estabilização da estufa.
const REPETICAO_MS = {
  incendio: 60 * 1000,
  temperaturaMuitoAlta: 60 * 1000,
  // Risco de fogo sem causa declarada: mesma urgencia, chave propria.
  fogoAgregado: 60 * 1000,
  alarmeProcesso: 30 * 60 * 1000,
};

function criarAlertasPush({ db, push, estado }) {
  // Ultimo estado notificado por aparelho, para avisar na BORDA (quando o
  // problema comeca) e nao a cada leitura enquanto ele durar.
  const ultimoEstadoNotificado = new Map();

  // Quando cada aviso tocou pela ultima vez, e se o produtor ja o viu.
  // Chave: `idHardware|evento`.
  const repeticoes = new Map();

  /// Decide entre o primeiro aviso e sua repetição periódica.
  /// A abertura da estufa no aplicativo reconhece o episódio atual.
  function deveAvisar({ idHardware, evento, ativo, subida, agoraMs }) {
    const chave = `${idHardware}|${evento}`;
    if (!ativo) {
      // Problema resolvido: esquece tudo, para o proximo episodio comecar limpo
      // e voltar a avisar mesmo que este tenha sido reconhecido.
      repeticoes.delete(chave);
      return false;
    }
    if (subida) {
      repeticoes.set(chave, { ultimoAvisoMs: agoraMs, reconhecido: false });
      return true;
    }

    const anterior = repeticoes.get(chave);
    // Sem registro (servidor reiniciou no meio do episodio): trata como subida.
    if (!anterior) {
      repeticoes.set(chave, { ultimoAvisoMs: agoraMs, reconhecido: false });
      return true;
    }
    if (anterior.reconhecido) return false;

    const intervalo = REPETICAO_MS[evento];
    if (!intervalo) return false;
    if (agoraMs - anterior.ultimoAvisoMs < intervalo) return false;

    anterior.ultimoAvisoMs = agoraMs;
    return true;
  }

  /// O produtor abriu o app nesta estufa: para de insistir no episodio atual.
  /// Nao apaga o estado — se o problema passar e voltar, avisa de novo.
  function reconhecer(idHardware) {
    for (const [chave, valor] of repeticoes) {
      if (chave.startsWith(`${idHardware}|`)) valor.reconhecido = true;
    }
  }

  function preferenciaPermite(preferencias, chaveEvento) {
    if (!preferencias) return true; // sem preferencia salva, o padrao e avisar
    const opcao = preferencias[chaveEvento];
    if (!opcao || typeof opcao !== 'object') return true;
    return opcao.notificar !== false;
  }

  // Com o app FECHADO quem decide o som e o canal do Android, nao o codigo do
  // app - entao respeitar o interruptor "Tocar" exige escolher o canal certo
  // aqui, na hora de enviar. Sem isto o produtor desligava o toque e continuava
  // sendo acordado, porque o canal seguia com a sirene.
  function preferenciaToca(preferencias, chaveEvento) {
    if (!preferencias) return true;
    const opcao = preferencias[chaveEvento];
    if (!opcao || typeof opcao !== 'object') return true;
    return opcao.tocarVibrar !== false;
  }

  async function notificarEvento({
    idHardware,
    evento,
    titulo,
    corpo,
    critico,
    validadeMs,
  }) {
    // Aparelho declarado MUDO: daqui em diante o servidor nao sabe em que estado
    // a estufa esta, entao para de fingir que sabe. Esquecer faz o retorno
    // contar como subida nova.
    //
    // Remove o estado anterior para que o retorno do aparelho seja avaliado
    // como uma nova transição. Isso independe da disponibilidade do push.
    if (evento === 'semComunicacao' && critico === true) {
      ultimoEstadoNotificado.delete(idHardware);
    }
    if (!push?.habilitado || !db.listarDispositivosPush) return;
    try {
      const inscritos = (await db.listarDispositivosPush(idHardware)).filter(
        (i) => preferenciaPermite(i.preferencias, evento),
      );
      if (inscritos.length === 0) return;

      // Um disparo por (toque, nome). O toque separa porque o canal - e
      // portanto o som - viaja na mensagem. O nome separa porque ele vem do
      // celular de quem cadastrou, e dois donos podem chamar a mesma estufa de
      // coisas diferentes; cada um recebe o titulo que reconhece.
      const grupos = new Map();
      for (const inscrito of inscritos) {
        const toca = preferenciaToca(inscrito.preferencias, evento);
        const nome = inscrito.nome || '';
        const chave = `${toca ? 'toca' : 'mudo'}|${nome}`;
        const grupo = grupos.get(chave) || { toca, nome, tokens: [] };
        grupo.tokens.push(inscrito.tokenPush);
        grupos.set(chave, grupo);
      }

      const invalidos = [];
      for (const grupo of grupos.values()) {
        const resultado = await push.enviar({
          tokens: grupo.tokens,
          // Nome no titulo, nao no corpo: quando varias estufas alertam
          // juntas o Android empilha os avisos e so o titulo sobrevive - sem
          // ele seriam tres "Risco de incendio" identicos.
          titulo: grupo.nome ? `${grupo.nome} · ${titulo}` : titulo,
          corpo,
          evento,
          critico,
          validadeMs,
          comToque: grupo.toca,
        });
        invalidos.push(...resultado.invalidos);
      }
      if (invalidos.length > 0 && db.removerTokensPushInvalidos) {
        await db.removerTokensPushInvalidos(invalidos);
      }
    } catch (error) {
      log.erro('Falha ao notificar push:', error.message);
    }
  }

  // Quando cada aparelho acompanhado foi visto pela ultima vez. Prefere o
  // estado ao vivo (desta sessao) e cai para o banco quando o servidor
  // reiniciou - senao um aparelho morto antes do restart nunca seria vigiado.
  async function listarAparelhosVigiados() {
    if (!db.listarAparelhosComPush) return [];
    const ids = await db.listarAparelhosComPush();
    const aparelhos = [];
    for (const idHardware of ids) {
      if (!idHardware || idHardware === ID_SIMULADOR) continue;
      let ultimoContatoMs = estado.ultimoContatoAoVivoMs(idHardware);
      if (!ultimoContatoMs && db.carregarUltimaLeitura) {
        const status = await db.carregarUltimaLeitura(idHardware);
        ultimoContatoMs = Number(status?.timestampLeitura) || 0;
      }
      aparelhos.push({ idHardware, ultimoContatoMs });
    }
    return aparelhos;
  }

  // Minutos vindos do ambiente, para afinar o vigia sem regravar o servidor.
  // Valor invalido ou ausente cai no padrao do watchdog.
  function minutosDoAmbiente(nome) {
    const minutos = Number(process.env[nome]);
    return Number.isFinite(minutos) && minutos > 0 ? minutos * 60 * 1000 : undefined;
  }

  const vigia = iniciarWatchdog({
    listarAparelhos: listarAparelhosVigiados,
    notificar: (aviso) => notificarEvento(aviso),
    limiteMs: minutosDoAmbiente('WATCHDOG_SILENCIO_MIN'),
    intervaloMs: minutosDoAmbiente('WATCHDOG_VERIFICACAO_MIN'),
  });

  // Compara a leitura nova com o ultimo estado avisado e dispara so na subida.
  async function avaliarAlertas(idHardware, status, config) {
    if (!idHardware || idHardware === ID_SIMULADOR) return;

    // O silêncio temporário reconhece o episódio atual. A preferência permanente
    // do buzzer não representa reconhecimento de um alarme específico.
    if (config?.modoSilencioso === true) reconhecer(idHardware);

    const fogoSensor = status.perigoChama === true;
    const tempMuitoAlta = status.riscoIncendio === true;
    const fogo = fogoSensor || tempMuitoAlta || status.alertaIncendio === true;
    // A condição térmica é independente da sirene local. Firmwares anteriores
    // utilizam `alarmeAtivo` como compatibilidade.
    const alarme = status.alertaTemperatura != null
      ? status.alertaTemperatura === true
      : status.alarmeAtivo === true;

    const anterior = ultimoEstadoNotificado.get(idHardware) || {};
    ultimoEstadoNotificado.set(idHardware, {
      fogo,
      alarme,
      fogoSensor,
      tempMuitoAlta,
    });

    // Duas causas, dois eventos: chama no sensor e temperatura de incendio sao
    // independentes, e o produtor pode querer desligar um sem perder o outro.
    // Cada um tem a sua propria borda, entao a temperatura subir depois de o
    // sensor ja ter disparado ainda avisa.
    const agoraMs = Date.now();
    const avisar = (evento, ativo, subida) =>
      deveAvisar({ idHardware, evento, ativo, subida, agoraMs });

    if (avisar('incendio', fogoSensor, fogoSensor && !anterior.fogoSensor)) {
      await notificarEvento({
        idHardware,
        evento: 'incendio',
        titulo: 'Risco de incêndio',
        corpo: 'O sensor de incêndio detectou chama. Verifique agora.',
        critico: true,
      });
    }
    if (
      avisar(
        'temperaturaMuitoAlta',
        tempMuitoAlta,
        tempMuitoAlta && !anterior.tempMuitoAlta,
      )
    ) {
      await notificarEvento({
        idHardware,
        evento: 'temperaturaMuitoAlta',
        titulo: 'Temperatura muito elevada',
        corpo:
          'A temperatura passou do limite de risco de incêndio. ' +
          'Verifique agora.',
        critico: true,
      });
    }
    // O aparelho pode reportar risco de fogo sem dizer qual causa (campo
    // agregado). Nesse caso o aviso sai como incendio, que e o mais grave dos
    // dois - calar seria pior. Chave de repeticao propria (`fogoAgregado`) para
    // nao brigar com a do sensor de chama.
    const fogoSemCausa = fogo && !fogoSensor && !tempMuitoAlta;
    if (
      avisar(
        'fogoAgregado',
        fogoSemCausa,
        fogoSemCausa && !anterior.fogo,
      )
    ) {
      await notificarEvento({
        idHardware,
        evento: 'incendio',
        titulo: 'Risco de incêndio',
        corpo: 'Indício de incêndio. Verifique agora.',
        critico: true,
      });
    }
    // Sem aviso proprio de falta de energia: o aparelho nao tem sensor de tensao
    // nem bateria, entao `temEnergia` e sempre true e ele nao consegue avisar
    // que esta morrendo. Quem cobre esse caso e o watchdog, pela ausencia -
    // manter um evento a parte prometeria uma distincao que o sistema nao sabe
    // fazer, e o produtor poderia desligar o aviso que de fato funciona
    // achando que este o cobria. Volta quando existir o sensor de tensao.
    const foraDaFaixa = alarme && !fogo;
    if (
      avisar('alarmeProcesso', foraDaFaixa, foraDaFaixa && !anterior.alarme)
    ) {
      await notificarEvento({
        idHardware,
        evento: 'alarmeProcesso',
        titulo: 'Temperatura fora da faixa',
        corpo: status.aviso || 'A temperatura saiu da faixa do ajuste.',
        critico: false,
      });
    }
  }

  return { notificarEvento, avaliarAlertas, reconhecer, vigia };
}

module.exports = {
  criarAlertasPush,
};
