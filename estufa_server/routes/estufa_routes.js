const express = require('express');

const {
  validarPayloadBotaoFisico,
  validarPayloadLeitura,
  validarPayloadSincronizacao,
} = require('../sync');
const { criarPayloadEsp32 } = require('../esp32_payload');

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

  // Caixa de comandos por aparelho (idHardware -> config pendente). O aparelho
  // real nao e alcancavel de fora: quem manda e ele, empurrando leituras. Entao
  // o comando do app fica aqui ate o proprio aparelho vir buscar em
  // GET /comandos. O LWW por campo continua sendo resolvido no aparelho.
  const comandosPendentes = new Map();

  function guardarComandoPendente(idHardware, comando) {
    const pendente = comandosPendentes.get(idHardware) || {};
    // Campos diferentes convivem; o mesmo campo e sobrescrito pelo mais novo,
    // que e o mesmo criterio que o aparelho aplicaria de qualquer forma.
    comandosPendentes.set(idHardware, { ...pendente, ...comando });
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

  router.get('/status', async (req, res) => {
    const dados = await lerDispositivo(req.query.idHardware);
    if (!dados) {
      res.status(404).json({
        erro: 'Aparelho sem leituras',
        idHardware: req.query.idHardware || null,
      });
      return;
    }
    res.json(dados);
  });


  router.get('/', async (_req, res) => {
    const dadosCompletos = simulador.lerCompleto();
    res.json(criarPayloadEsp32(dadosCompletos, 'simulador', { tokenConfigurado }));
  });

  router.get('/dados', async (_req, res) => {
    const dadosCompletos = simulador.lerCompleto();
    res.json(criarPayloadEsp32(dadosCompletos, 'simulador', { tokenConfigurado }));
  });

  // Historico persistido na nuvem, para o relatorio remoto preencher os
  // periodos em que o app esteve fechado. Leitura publica (mesmo criterio de
  // GET /status). Parametros opcionais: inicio, fim (ms Unix), idHardware.
  router.get('/historico', async (req, res) => {
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
      res.status(500).json({
        erro: 'Falha ao carregar historico',
        detalhe: error.message,
      });
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
  // — e se o comando se perder no caminho, o app reenvia pela fila que ja tem.
  router.get('/comandos', authMiddleware, (req, res) => {
    const idHardware = req.query.idHardware;
    if (!idHardware) {
      res.status(400).json({ erro: 'idHardware obrigatorio' });
      return;
    }

    const comando = comandosPendentes.get(idHardware) || null;
    comandosPendentes.delete(idHardware);
    res.json({ idHardware, comando });
  });

  // Ingestao de telemetria vinda do hardware (ou de outra ponte). Persiste na
  // nuvem quando disponivel; se a nuvem estiver fora, guarda no buffer offline
  // para reenvio posterior. Assim a arquitetura fica pronta para o ESP32 real
  // sem depender do polling do simulador.
  router.post('/leitura', authMiddleware, async (req, res) => {
    const status = { ...req.body };
    delete status.config;
    const validacao = validarPayloadLeitura(status);

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
    }

    if (!db.estaHabilitado()) {
      res.json({ sucesso: true, persistido: false, motivo: 'persistencia_desabilitada' });
      return;
    }

    try {
      await db.persistirLeituraBufferizada(dados);
      res.json({ sucesso: true, persistido: true });
    } catch (error) {
      if (!buffer) {
        res.status(503).json({
          sucesso: false,
          erro: 'Persistencia indisponivel',
          detalhe: error.message,
        });
        return;
      }

      try {
        await buffer.adicionar(dados);
        res.json({ sucesso: true, persistido: false, motivo: 'bufferizado' });
      } catch (erroBuffer) {
        res.status(500).json({
          sucesso: false,
          erro: 'Falha ao guardar leitura no buffer',
          detalhe: erroBuffer.message,
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
