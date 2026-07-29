const express = require('express');

const {
  validarPayloadBotaoFisico,
  validarPayloadLeitura,
  validarPayloadSincronizacao,
} = require('../sync');
const { criarPayloadEsp32 } = require('../esp32_payload');
const { iniciarWatchdog } = require('../watchdog');
const {
  iniciarAgendador,
  validarAgendamento,
} = require('../agendamentos');
const {
  criarRegistroLeitura,
  deveSalvarLeitura,
} = require('../storage_policy');

const ID_SIMULADOR = 'ESP32_REALISTIC_V2';

function createEstufaRouter({
  simulador,
  db,
  authMiddleware,
  tokenConfigurado = false,
  buffer = null,
  push = null,
  chavesAparelhos = null,
}) {
  const router = express.Router();

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
      console.error('Falha ao notificar push:', error.message);
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
      const aoVivo = dispositivosAoVivo.get(idHardware);
      let ultimoContatoMs = aoVivo?.recebidoMs ?? 0;
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
    const alarme = status.alarmeAtivo === true;

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

  // Estado ao vivo por aparelho (idHardware -> { status, config, recebidoMs }),
  // alimentado pelos POST /leitura dos aparelhos reais. O simulador continua
  // sendo o aparelho ESP32_REALISTIC_V2, servido do seu proprio modelo, sem se
  // misturar com os reais.
  const dispositivosAoVivo = new Map();
  const ultimasLeiturasPersistidas = new Map();

  // Caixa de comandos por aparelho (idHardware -> config pendente). O aparelho
  // real nao e alcancavel de fora: quem manda e ele, empurrando leituras. Entao
  // o comando do app fica aqui ate o proprio aparelho vir buscar em
  // GET /comandos. O LWW por campo continua sendo resolvido no aparelho.
  const comandosPendentes = new Map();

  // O plano gratuito recicla o processo com frequencia; sem espelhar a caixa no
  // banco, um ajuste feito de longe sumia em silencio se o servidor reiniciasse
  // antes de o aparelho buscar. O mapa segue sendo a verdade em memoria; o
  // banco e so o backup de restart (falha nele nao derruba o comando).
  if (db?.carregarComandosPendentes && db.estaHabilitado?.()) {
    db.carregarComandosPendentes()
      .then((pendentes) => {
        for (const { idHardware, comando } of pendentes) {
          if (!comandosPendentes.has(idHardware)) {
            comandosPendentes.set(idHardware, comando);
          }
        }
        if (pendentes.length > 0) {
          console.log(`Comandos pendentes restaurados: ${pendentes.length}`);
        }
      })
      .catch((error) => {
        console.error('Falha ao restaurar comandos pendentes:', error.message);
      });
  }

  function guardarComandoPendente(idHardware, comando) {
    const pendente = comandosPendentes.get(idHardware) || {};
    // Campos diferentes convivem; o mesmo campo e sobrescrito pelo mais novo,
    // que e o mesmo criterio que o aparelho aplicaria de qualquer forma.
    const fundido = { ...pendente, ...comando };
    comandosPendentes.set(idHardware, fundido);
    if (db?.salvarComandoPendente) {
      db.salvarComandoPendente(idHardware, fundido).catch((error) => {
        console.error('Falha ao persistir comando pendente:', error.message);
      });
    }
  }

  // Aplica os agendamentos vencidos. Entram pela mesma caixa de comandos de um
  // ajuste feito a mao, entao o firmware nao precisou aprender nada novo: para
  // ele, um agendamento e indistinguivel de alguem mexendo no app naquela hora.
  const agendador = iniciarAgendador({
    listarAgendamentos: () =>
      db?.listarAgendamentos && db.estaHabilitado?.()
        ? db.listarAgendamentos()
        : [],
    // O alvo vigente resolve o "+10 F" no instante de aplicar, nao no de agendar.
    configDoAparelho: (idHardware) => dispositivosAoVivo.get(idHardware)?.config,
    aplicarComando: (idHardware, comando) => {
      // O simulador nao busca a caixa de comandos - ele e servido do proprio
      // modelo, aqui dentro. Sem este desvio, um agendamento para ele ficava na
      // caixa para sempre: o aviso chegava e o ajuste nunca mudava, dando a
      // impressao de recurso quebrado justo na superficie feita para testar.
      if (!idHardware || idHardware === ID_SIMULADOR) {
        simulador.sincronizarConfiguracao(comando);
      } else {
        guardarComandoPendente(idHardware, comando);
      }
      console.log(
        `Agendamento aplicado (${idHardware}): ${JSON.stringify(comando)}`,
      );
    },
    remover: (id) => db?.removerAgendamento?.(id),
  });

  // Campos de ajuste e o timestamp que decide o LWW de cada um.
  const CAMPO_TIMESTAMP = {
    temperaturaMeta: 'tempTimestamp',
    umidadeMeta: 'umidTimestamp',
    modoSilencioso: 'modoSilenciosoTimestamp',
    buzzerAtivo: 'buzzerTimestamp',
  };

  // Um comando so deixa de estar pendente quando o proprio aparelho reporta
  // aquele campo com timestamp igual ou mais novo - ou seja, quando ele
  // confirma que aplicou. Ate la a entrega se repete, o que e inofensivo
  // (o LWW no aparelho torna reaplicar idempotente) e cobre o caso de o
  // aparelho reiniciar logo depois de buscar.
  function limparPendentesConfirmados(idHardware, configDoAparelho) {
    const pendente = comandosPendentes.get(idHardware);
    if (!pendente || !configDoAparelho) return;

    const restante = { ...pendente };
    for (const [campo, chaveTimestamp] of Object.entries(CAMPO_TIMESTAMP)) {
      if (!Object.hasOwn(restante, campo)) continue;
      const tsPendente = Number(restante[chaveTimestamp]);
      const tsAparelho = Number(configDoAparelho[chaveTimestamp]);
      if (Number.isFinite(tsAparelho) && tsAparelho >= tsPendente) {
        delete restante[campo];
        delete restante[chaveTimestamp];
      }
    }

    if (Object.keys(restante).length === 0) {
      comandosPendentes.delete(idHardware);
      if (db?.removerComandoPendente) {
        db.removerComandoPendente(idHardware).catch((error) => {
          console.error('Falha ao limpar comando pendente:', error.message);
        });
      }
    } else {
      comandosPendentes.set(idHardware, restante);
      if (db?.salvarComandoPendente) {
        db.salvarComandoPendente(idHardware, restante).catch((error) => {
          console.error('Falha ao persistir comando pendente:', error.message);
        });
      }
    }
  }

  // O que o app deve ver: a config do aparelho com o comando pendente por cima.
  // Sem isso a tela voltava ao valor antigo poucos segundos depois de o usuario
  // mexer, ate o aparelho buscar o comando e reportar de volta.
  function configComPendente(idHardware, config) {
    const pendente = comandosPendentes.get(idHardware);
    if (!pendente) return { config, aguardandoAparelho: false };
    return { config: { ...config, ...pendente }, aguardandoAparelho: true };
  }

  async function lerDispositivo(idHardware) {
    if (!idHardware || idHardware === ID_SIMULADOR) {
      return simulador.lerCompleto();
    }
    const emMemoria = dispositivosAoVivo.get(idHardware);
    if (emMemoria) {
      return { status: emMemoria.status, config: emMemoria.config };
    }
    // Sob demanda: ultima leitura/config do banco (aparelho que ainda nao
    // empurrou nesta sessao do servidor).
    if (db.carregarUltimaLeitura) {
      const status = await db.carregarUltimaLeitura(idHardware);
      if (status) {
        const config = db.carregarConfiguracao
          ? await db.carregarConfiguracao(idHardware)
          : null;
        const registro = { status, config: config || {}, recebidoMs: 0 };
        dispositivosAoVivo.set(idHardware, registro);
        return { status, config: registro.config };
      }
    }
    return null;
  }

  // Publico de proposito: e o detector de deploy. Hoje descobrimos um deploy
  // que nao subiu so porque um curl manual estranhou a resposta; com o commit
  // exposto aqui, "o que esta no ar?" vira uma pergunta de um segundo. Nao
  // carrega dado de estufa nenhum.
  const iniciadoEmMs = Date.now();
  router.get('/versao', (_req, res) => {
    const commit = (process.env.RENDER_GIT_COMMIT || '').slice(0, 7) || null;
    res.json({
      commit,
      uptimeSegundos: Math.round((Date.now() - iniciadoEmMs) / 1000),
    });
  });

  // Leituras tambem exigem token: telemetria da estufa e dado do produtor, nao
  // publico. O app ja envia a chave em toda chamada; o custo real e que uma
  // estufa cadastrada sem chave deixa de ler pela nuvem.
  router.get('/status', authMiddleware, async (req, res) => {
    const idHardware = req.query.idHardware;
    const dados = await lerDispositivo(idHardware);
    if (!dados) {
      res.status(404).json({
        erro: 'Aparelho sem leituras',
        idHardware: idHardware || null,
      });
      return;
    }

    if (!idHardware || idHardware === ID_SIMULADOR) {
      res.json(dados);
      return;
    }

    const { config, aguardandoAparelho } = configComPendente(
      idHardware,
      dados.config,
    );
    res.json({ ...dados, config, aguardandoAparelho });
  });


  router.get('/', authMiddleware, async (_req, res) => {
    const dadosCompletos = simulador.lerCompleto();
    res.json(criarPayloadEsp32(dadosCompletos, 'simulador', { tokenConfigurado }));
  });

  router.get('/dados', authMiddleware, async (_req, res) => {
    const dadosCompletos = simulador.lerCompleto();
    res.json(criarPayloadEsp32(dadosCompletos, 'simulador', { tokenConfigurado }));
  });

  // Historico persistido na nuvem, para o relatorio remoto preencher os
  // periodos em que o app esteve fechado. Autenticado como o /status.
  // Parametros opcionais: inicio, fim (ms Unix), idHardware.
  router.get('/historico', authMiddleware, async (req, res) => {
    if (!db.estaHabilitado?.()) {
      res.json({ leituras: [], persistencia: false });
      return;
    }

    const inicioMs = Number(req.query.inicio);
    const fimMs = Number(req.query.fim);
    const idHardware = req.query.idHardware || undefined;

    try {
      const leituras = await db.carregarHistorico(idHardware, {
        inicioMs: Number.isFinite(inicioMs) ? inicioMs : undefined,
        fimMs: Number.isFinite(fimMs) ? fimMs : undefined,
      });
      res.json({ leituras, persistencia: true });
    } catch (error) {
      // O detalhe fica no log: mensagens de erro do banco podem expor caminhos
      // e configuracao internos a qualquer cliente.
      console.error('Falha ao carregar historico:', error.message);
      res.status(500).json({ erro: 'Falha ao carregar historico' });
    }
  });

  router.post('/sincronizar', authMiddleware, async (req, res) => {
    const configDoApp = req.body;
    const validacao = validarPayloadSincronizacao(configDoApp);

    if (!validacao.valido) {
      res.status(400).json({
        sucesso: false,
        erro: 'Payload invalido',
        detalhes: validacao.erros,
      });
      return;
    }

    const idHardware = configDoApp.idHardware;
    const paraAparelhoReal = idHardware && idHardware !== ID_SIMULADOR;

    // Comando para aparelho real nao pode ser aplicado aqui: quem manda no
    // equipamento e o proprio aparelho. Fica pendente ate ele buscar. Sem isso
    // o comando caia no simulador e o app dizia "aplicado" sem nada acontecer.
    if (paraAparelhoReal) {
      const comando = { ...configDoApp };
      delete comando.idHardware;
      guardarComandoPendente(idHardware, comando);

      const resultado = {
        sucesso: true,
        pendente: true,
        idHardware,
        aviso: 'Comando guardado; sera aplicado quando o aparelho buscar.',
      };
      try {
        await db.salvarComandoSync(configDoApp, resultado);
      } catch (error) {
        console.error('Falha ao salvar comando no banco:', error.message);
      }
      res.json(resultado);
      return;
    }

    const resultado = simulador.sincronizarConfiguracao(configDoApp);
    try {
      await db.salvarComandoSync(configDoApp, resultado);
    } catch (error) {
      console.error('Falha ao salvar comando no banco:', error.message);
    }
    res.json(resultado);
  });

  // O aparelho pergunta se tem ajuste esperando por ele. Responder e entregar:
  // o proprio POST /leitura seguinte, ja com a config nova, serve de confirmacao
  // â€” e se o comando se perder no caminho, o app reenvia pela fila que ja tem.
  router.get('/comandos', authMiddleware, (req, res) => {
    const idHardware = req.query.idHardware;
    if (!idHardware) {
      res.status(400).json({ erro: 'idHardware obrigatorio' });
      return;
    }

    const comando = comandosPendentes.get(idHardware) || null;
    res.json({ idHardware, comando });
  });

  // ---- Agendamentos de ajuste ----
  // "As 14h deixe em 120 F" / "suba 10 F". O aviso ao produtor e um alarme local
  // no celular (funciona sem internet); estas rotas cuidam apenas de TROCAR O
  // ALVO na hora marcada, o que o celular nao consegue fazer com o app fechado.
  // Vencido, o agendamento cai na mesma caixa de comandos de um ajuste manual.

  router.post('/agendamentos', authMiddleware, async (req, res) => {
    const agoraMs = Date.now();
    const validacao = validarAgendamento(req.body, agoraMs);
    if (!validacao.valido) {
      res.status(400).json({
        sucesso: false,
        erro: 'Agendamento invalido',
        detalhes: validacao.erros,
      });
      return;
    }
    if (!db.salvarAgendamento || !db.estaHabilitado?.()) {
      // Sem banco o agendamento nao sobreviveria ao proximo reciclo do processo.
      // Melhor recusar do que aceitar algo que vai sumir calado.
      res.status(503).json({ sucesso: false, erro: 'sem_persistencia' });
      return;
    }

    const { idHardware, aplicarEmMs, ...resto } = req.body;
    const payload = {};
    for (const campo of [
      'temperaturaMeta',
      'temperaturaDelta',
      'umidadeMeta',
      'umidadeDelta',
    ]) {
      if (resto[campo] !== undefined) payload[campo] = Number(resto[campo]);
    }

    try {
      const id = await db.salvarAgendamento(
        idHardware.trim(),
        Number(aplicarEmMs),
        payload,
      );
      res.json({ sucesso: true, id: id === null ? null : String(id) });
    } catch (error) {
      console.error('Falha ao salvar agendamento:', error.message);
      res.status(500).json({ sucesso: false, erro: 'Falha ao salvar' });
    }
  });

  router.get('/agendamentos', authMiddleware, async (req, res) => {
    const idHardware = req.query.idHardware;
    if (!idHardware) {
      res.status(400).json({ erro: 'idHardware obrigatorio' });
      return;
    }
    if (!db.listarAgendamentos) {
      res.json({ idHardware, agendamentos: [] });
      return;
    }
    try {
      const agendamentos = await db.listarAgendamentos(String(idHardware));
      res.json({ idHardware, agendamentos });
    } catch (error) {
      console.error('Falha ao listar agendamentos:', error.message);
      res.status(500).json({ erro: 'Falha ao listar' });
    }
  });

  router.delete('/agendamentos/:id', authMiddleware, async (req, res) => {
    const idHardware = req.query.idHardware;
    if (!idHardware) {
      res.status(400).json({ erro: 'idHardware obrigatorio' });
      return;
    }
    if (!db.removerAgendamento) {
      res.status(503).json({ sucesso: false, erro: 'sem_persistencia' });
      return;
    }
    try {
      const removido = await db.removerAgendamento(
        req.params.id,
        String(idHardware),
      );
      res.json({ sucesso: removido });
    } catch (error) {
      console.error('Falha ao remover agendamento:', error.message);
      res.status(500).json({ sucesso: false, erro: 'Falha ao remover' });
    }
  });

  // O app registra aqui o token FCM do celular para cada estufa que acompanha.
  // Autenticado: sem isso qualquer um inscreveria um celular nos alertas de uma
  // estufa alheia.
  router.post('/push/dispositivos', authMiddleware, async (req, res) => {
    const { tokenPush, idHardware, plataforma, preferencias, nome } = req.body || {};
    if (typeof tokenPush !== 'string' || tokenPush.trim() === '') {
      res.status(400).json({ erro: 'tokenPush obrigatorio' });
      return;
    }
    if (typeof idHardware !== 'string' || idHardware.trim() === '') {
      res.status(400).json({ erro: 'idHardware obrigatorio' });
      return;
    }
    if (!db.registrarDispositivoPush) {
      res.json({ sucesso: true, registrado: false, motivo: 'sem_persistencia' });
      return;
    }

    try {
      await db.registrarDispositivoPush({
        tokenPush: tokenPush.trim(),
        idHardware: idHardware.trim(),
        plataforma,
        preferencias: preferencias ?? null,
        nome: typeof nome === 'string' && nome.trim() !== '' ? nome.trim() : null,
      });
      res.json({ sucesso: true, registrado: true, push: Boolean(push?.habilitado) });
    } catch (error) {
      console.error('Falha ao registrar dispositivo push:', error.message);
      res.status(500).json({ erro: 'Falha ao registrar dispositivo' });
    }
  });

  router.delete('/push/dispositivos', authMiddleware, async (req, res) => {
    const { tokenPush, idHardware } = req.body || {};
    if (typeof tokenPush !== 'string' || tokenPush.trim() === '') {
      res.status(400).json({ erro: 'tokenPush obrigatorio' });
      return;
    }
    if (!db.removerDispositivoPush) {
      res.json({ sucesso: true });
      return;
    }

    try {
      await db.removerDispositivoPush({
        tokenPush: tokenPush.trim(),
        idHardware: typeof idHardware === 'string' ? idHardware.trim() : null,
      });
      res.json({ sucesso: true });
    } catch (error) {
      console.error('Falha ao remover dispositivo push:', error.message);
      res.status(500).json({ erro: 'Falha ao remover dispositivo' });
    }
  });

  // Roda o watchdog na hora, sem esperar o ciclo. Serve para testar o aviso de
  // silencio sem precisar desligar a estufa e cronometrar 15 minutos.
  router.post('/push/verificar-silencio', authMiddleware, async (_req, res) => {
    if (!vigia) {
      res.status(503).json({ erro: 'Watchdog indisponivel' });
      return;
    }
    try {
      await vigia.verificar();
      res.json({ sucesso: true });
    } catch (error) {
      console.error('Falha ao verificar silencio:', error.message);
      res.status(500).json({ erro: 'Falha ao verificar silencio' });
    }
  });

  // Roda o agendador na hora, sem esperar o ciclo de 30 s. Mesmo motivo da rota
  // do watchdog: testar sem cronometrar.
  router.post('/agendamentos/verificar', authMiddleware, async (_req, res) => {
    if (!agendador) {
      res.status(503).json({ erro: 'Agendador indisponivel' });
      return;
    }
    try {
      await agendador.verificar();
      res.json({ sucesso: true });
    } catch (error) {
      console.error('Falha ao verificar agendamentos:', error.message);
      res.status(500).json({ erro: 'Falha ao verificar agendamentos' });
    }
  });

  // ---- Chave por aparelho ----
  // Ambas as rotas ficam ATRAS do authMiddleware, e essa foi a decisao de
  // seguranca do desenho. O TOFU puro (rota aberta, primeiro a registrar vence)
  // deixaria qualquer um reivindicar um `idHardware` antes do aparelho - e o id
  // nao e segredo: aparece em toda resposta de /status. Exigir a credencial
  // atual mantem a ancora onde ela ja esta hoje (quem tem a chave global e o
  // produtor) e nao abre exposicao nova. O aparelho consegue registrar porque a
  // chave dele ainda E a global; depois disso passa a usar a propria.
  router.post('/aparelhos/chave', authMiddleware, async (req, res) => {
    const idHardware = (req.body?.idHardware || '').trim();
    const chave = (req.body?.chave || '').trim();
    if (!idHardware || !chave) {
      res.status(400).json({ erro: 'idHardware e chave obrigatorios' });
      return;
    }
    if (!db.registrarChaveAparelho) {
      res.status(503).json({ erro: 'Persistencia indisponivel' });
      return;
    }

    try {
      const { estado } = await db.registrarChaveAparelho(idHardware, chave);
      if (estado === 'registrada' || estado === 'ja_registrada') {
        chavesAparelhos?.anotar(idHardware, chave);
        res.json({ sucesso: true, estado });
        return;
      }
      if (estado === 'conflito') {
        // Nao vaza a chave guardada nem confirma qual e: so diz que ja tem dono.
        res.status(409).json({
          sucesso: false,
          erro: 'Aparelho ja tem chave registrada',
          detalhe: 'Para trocar, use a rotacao com a chave atual.',
        });
        return;
      }
      res.status(503).json({ sucesso: false, erro: estado });
    } catch (error) {
      console.error('Falha ao registrar chave do aparelho:', error.message);
      res.status(500).json({ erro: 'Falha ao registrar chave' });
    }
  });

  // Rotacao: quem gera uma chave nova no aparelho conhece as duas por um
  // instante, e e o aparelho que avisa a nuvem. Exigir a antiga e o que impede
  // roubar o aparelho sabendo so o idHardware - e e o que tranca o dono antigo
  // para fora depois de uma venda.
  router.post('/aparelhos/chave/rotacionar', authMiddleware, async (req, res) => {
    const idHardware = (req.body?.idHardware || '').trim();
    const chaveAtual = (req.body?.chaveAtual || '').trim();
    const chaveNova = (req.body?.chaveNova || '').trim();
    if (!idHardware || !chaveAtual || !chaveNova) {
      res
        .status(400)
        .json({ erro: 'idHardware, chaveAtual e chaveNova obrigatorios' });
      return;
    }
    if (chaveAtual === chaveNova) {
      res.status(400).json({ erro: 'A chave nova tem de ser diferente' });
      return;
    }
    if (!db.rotacionarChaveAparelho) {
      res.status(503).json({ erro: 'Persistencia indisponivel' });
      return;
    }

    try {
      const { estado } = await db.rotacionarChaveAparelho(
        idHardware,
        chaveAtual,
        chaveNova,
      );
      if (estado === 'rotacionada') {
        chavesAparelhos?.anotar(idHardware, chaveNova);
        res.json({ sucesso: true });
        return;
      }
      if (estado === 'chave_antiga_nao_bate') {
        res.status(403).json({ sucesso: false, erro: 'Chave atual nao confere' });
        return;
      }
      res.status(503).json({ sucesso: false, erro: estado });
    } catch (error) {
      console.error('Falha ao rotacionar chave do aparelho:', error.message);
      res.status(500).json({ erro: 'Falha ao rotacionar chave' });
    }
  });

  // Push de teste: confirma a ponta a ponta (credencial, token, canal) sem
  // precisar provocar um incendio de verdade.
  router.post('/push/teste', authMiddleware, async (req, res) => {
    const idHardware = (req.body?.idHardware || '').trim();
    if (!idHardware) {
      res.status(400).json({ erro: 'idHardware obrigatorio' });
      return;
    }
    if (!push?.habilitado) {
      res.status(503).json({ erro: 'Push desabilitado no servidor' });
      return;
    }

    try {
      // Tambem por nome, como os avisos de verdade: o teste so serve se
      // mostrar o que o produtor vai realmente ler na barra.
      const inscritos = await db.listarDispositivosPush(idHardware);
      const porNome = new Map();
      for (const inscrito of inscritos) {
        const nome = inscrito.nome || '';
        const tokens = porNome.get(nome) || [];
        tokens.push(inscrito.tokenPush);
        porNome.set(nome, tokens);
      }

      let enviados = 0;
      const invalidos = [];
      for (const [nome, tokens] of porNome) {
        const resultado = await push.enviar({
          tokens,
          titulo: nome ? `${nome} · Sentinela Smart` : 'Sentinela Smart',
          corpo: 'Notificação de teste. O aviso remoto está funcionando.',
          evento: 'alarmeProcesso',
        });
        enviados += resultado.enviados;
        invalidos.push(...resultado.invalidos);
      }
      if (invalidos.length > 0 && db.removerTokensPushInvalidos) {
        await db.removerTokensPushInvalidos(invalidos);
      }
      res.json({ sucesso: true, enviados, inscritos: inscritos.length });
    } catch (error) {
      console.error('Falha no push de teste:', error.message);
      res.status(500).json({ erro: 'Falha ao enviar push de teste' });
    }
  });

  // Ingestao de telemetria vinda do hardware (ou de outra ponte). Persiste na
  // nuvem quando disponivel; se a nuvem estiver fora, guarda no buffer offline
  // para reenvio posterior. Assim a arquitetura fica pronta para o ESP32 real
  // sem depender do polling do simulador.
  router.post('/leitura', authMiddleware, async (req, res) => {
    const status = { ...req.body };
    delete status.config;
    const validacao = validarPayloadLeitura(status, req.body.config);

    if (!validacao.valido) {
      res.status(400).json({
        sucesso: false,
        erro: 'Payload invalido',
        detalhes: validacao.erros,
      });
      return;
    }

    status.fonte = status.fonte || 'hardware';
    const dados = { status, config: req.body.config };

    // Alimenta o estado ao vivo DAQUELE aparelho (nao mistura com o simulador).
    // O timestamp servido usa a hora de recebimento (Date.now()) para o app
    // medir a staleness sem depender do relogio do ESP; o historico (dados)
    // mantem o timestamp original do aparelho.
    const idHw = status.idHardware;
    if (idHw && idHw !== ID_SIMULADOR) {
      dispositivosAoVivo.set(idHw, {
        status: { ...status, timestampLeitura: Date.now() },
        config: req.body.config || dispositivosAoVivo.get(idHw)?.config || {},
        recebidoMs: Date.now(),
      });
      // A leitura que o aparelho empurra carrega a config dele: e por ela que
      // sabemos se o comando pendente ja foi obedecido.
      limparPendentesConfirmados(idHw, req.body.config);
      // Avisa o produtor no celular quando um problema COMECA. Nao aguarda: a
      // resposta ao aparelho nao pode depender do FCM.
      avaliarAlertas(idHw, status).catch((error) =>
        console.error('Falha ao avaliar alertas:', error.message),
      );
    }

    if (!db.estaHabilitado()) {
      res.json({ sucesso: true, persistido: false, motivo: 'persistencia_desabilitada' });
      return;
    }

    const agoraMs = Date.now();
    const registro = criarRegistroLeitura(status, dados.config, agoraMs);
    const ultimaPersistida = ultimasLeiturasPersistidas.get(idHw);
    const decisao = deveSalvarLeitura({
      ultimaLeitura: ultimaPersistida,
      status,
      config: dados.config,
      agoraMs,
    });

    if (!decisao.salvar) {
      res.json({
        sucesso: true,
        persistido: false,
        motivo: decisao.motivo,
      });
      return;
    }

    try {
      await db.persistirLeituraBufferizada(dados);
      ultimasLeiturasPersistidas.set(idHw, registro);
      res.json({
        sucesso: true,
        persistido: true,
        motivo: decisao.motivo,
      });
    } catch (error) {
      if (!buffer) {
        console.error('Persistencia indisponivel:', error.message);
        res.status(503).json({
          sucesso: false,
          erro: 'Persistencia indisponivel',
        });
        return;
      }

      try {
        await buffer.adicionar(dados);
        ultimasLeiturasPersistidas.set(idHw, registro);
        res.json({
          sucesso: true,
          persistido: false,
          motivo: 'bufferizado',
          motivoAmostragem: decisao.motivo,
        });
      } catch (erroBuffer) {
        console.error('Falha ao guardar leitura no buffer:', erroBuffer.message);
        res.status(500).json({
          sucesso: false,
          erro: 'Falha ao guardar leitura no buffer',
        });
      }
    }
  });

  router.post('/debug/botao-fisico', authMiddleware, async (req, res) => {
    const { tipo, valor } = req.body;
    const validacao = validarPayloadBotaoFisico(req.body);

    if (!validacao.valido) {
      res.status(400).json({
        sucesso: false,
        erro: 'Payload invalido',
        detalhes: validacao.erros,
      });
      return;
    }

    simulador.simularBotaoFisico(tipo, valor);
    try {
      await db.salvarConfiguracaoSnapshot(simulador.lerCompleto());
    } catch (error) {
      console.error('Falha ao salvar ajuste fisico no banco:', error.message);
    }
    res.json({ msg: `Simulado botao fisico: ${tipo} -> ${valor}` });
  });

  return router;
}

module.exports = {
  createEstufaRouter,
};
