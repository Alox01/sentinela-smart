const { iniciarWatchdog } = require('../watchdog');
const { log } = require('../log');
const { ID_SIMULADOR } = require('./estado_estufa');

// Quem decide se o celular toca. Separado das rotas de push (que so cadastram e
// descadastram token) porque este e o outro lado do assunto: aqui e a leitura
// que chega que vira aviso, e quem chama e a rota de leitura.
function criarAlertasPush({ db, push, estado }) {
  // Ultimo estado notificado por aparelho, para avisar na BORDA (quando o
  // problema comeca) e nao a cada leitura enquanto ele durar.
  const ultimoEstadoNotificado = new Map();

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
  async function avaliarAlertas(idHardware, status) {
    if (!idHardware || idHardware === ID_SIMULADOR) return;

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
    if (fogoSensor && !anterior.fogoSensor) {
      await notificarEvento({
        idHardware,
        evento: 'incendio',
        titulo: 'Risco de incêndio',
        corpo: 'O sensor de incêndio detectou chama. Verifique agora.',
        critico: true,
      });
    }
    if (tempMuitoAlta && !anterior.tempMuitoAlta) {
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
    // dois - calar seria pior.
    if (fogo && !anterior.fogo && !fogoSensor && !tempMuitoAlta) {
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
    if (alarme && !anterior.alarme && !fogo) {
      await notificarEvento({
        idHardware,
        evento: 'alarmeProcesso',
        titulo: 'Temperatura fora da faixa',
        corpo: status.aviso || 'A temperatura saiu da faixa do ajuste.',
        critico: false,
      });
    }
  }

  return { notificarEvento, avaliarAlertas, vigia };
}

module.exports = {
  criarAlertasPush,
};
