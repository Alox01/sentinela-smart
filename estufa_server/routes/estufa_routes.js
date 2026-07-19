const express = require('express');

const {
  validarPayloadBotaoFisico,
  validarPayloadLeitura,
  validarPayloadSincronizacao,
} = require('../sync');
const { criarPayloadEsp32 } = require('../esp32_payload');
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
}) {
  const router = express.Router();

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

  // Campos de ajuste e o timestamp que decide o LWW de cada um.
  const CAMPO_TIMESTAMP = {
    temperaturaMeta: 'tempTimestamp',
    umidadeMeta: 'umidTimestamp',
    modoSilencioso: 'modoSilenciosoTimestamp',
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
