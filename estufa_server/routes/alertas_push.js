const { iniciarWatchdog } = require('../watchdog');
const { log } = require('../log');
const { ID_SIMULADOR } = require('./estado_estufa');

// Quem decide se o celular toca. Separado das rotas de push (que so cadastram e
// descadastram token) porque este e o outro lado do assunto: aqui e a leitura
// que chega que vira aviso, e quem chama e a rota de leitura.
// De quanto em quanto tempo um aviso volta a tocar enquanto o problema DURA.
//
// Avisar so na subida deixava um buraco caro: quem nao ouviu o primeiro toque
// nao ouve mais nada, e a estufa passa a noite fria. Pior no fogo, onde o
// primeiro aviso perdido e o unico que existia.
//
// Fogo e superaquecimento repetem de minuto em minuto porque a resposta e sair
// agora. Temperatura fora da faixa espera 30 min: e o tempo de ir ate a estufa,
// mexer na fornalha e o calor responder — cobrar antes disso e cobrar por algo
// que ja esta a caminho. Mais curto que isso vira alarme de carro, e o desfecho
// pior de todos e o produtor desligar a notificacao inteira.
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

  /// O aviso deve sair agora? Cobre a subida (problema comecando) e a
  /// repeticao (problema durando sem ninguem dar sinal de vida).
  ///
  /// `reconhecido` vem de o produtor abrir o app na estufa que esta alarmando —
  /// ver a rota `/push/reconhecer`. Nao da para saber que ele DISPENSOU a
  /// notificacao: com o app fechado quem a desenha e o Android, e deslizar para
  /// o lado nao avisa ninguem. Abrir o app e o sinal mais proximo de "eu vi" que
  /// existe sem inventar certeza.
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
    // Sem isto, um aparelho que fica horas desligado e volta AINDA fora da faixa
    // nao avisa ninguem: a comparacao e com o que o servidor sabia antes de ele
    // sumir, conclui "ja estava assim" e cala. Aconteceu em campo — estufa
    // desligada de noite, religada fria de manha, nenhum aviso.
    //
    // Antes do `push.habilitado`: isto e sobre o que o servidor SABE, e nao
    // sobre conseguir avisar.
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

    // Silencio momentaneo apertado no aparelho vale como "eu vi": ninguem aperta
    // silenciar sem o alarme estar tocando na frente dele. Para de insistir no
    // celular pelo episodio em curso.
    //
    // Diferente de DESLIGAR o buzzer (`buzzerAtivo`), que e preferencia e pode
    // ter sido decidida semanas atras — nao diz nada sobre este alarme. Um vale
    // como reacao; o outro, nao.
    if (config?.modoSilencioso === true) reconhecer(idHardware);

    const fogoSensor = status.perigoChama === true;
    const tempMuitoAlta = status.riscoIncendio === true;
    const fogo = fogoSensor || tempMuitoAlta || status.alertaIncendio === true;
    // A CONDICAO de temperatura fora da faixa, nao "a sirene esta tocando".
    // `alarmeAtivo` fica false quando o produtor desliga a sirene daquele
    // aparelho (ou pede os 10 min de silencio), e usar isso aqui fazia a sirene
    // da estufa decidir se o celular avisava - apagando, sem dizer nada, as
    // preferencias de notificacao que o produtor tinha configurado. Sao canais
    // diferentes: desligar o barulho na estufa e um pedido sobre o barulho ali.
    //
    // `alertaTemperatura` chega da v1.19.0 em diante; antes dela so havia
    // `alarmeAtivo`, e um aparelho com firmware velho continua avisando como
    // antes em vez de parar de avisar.
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
