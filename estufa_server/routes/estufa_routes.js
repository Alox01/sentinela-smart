const express = require('express');

const {
  validarPayloadBotaoFisico,
  validarPayloadLeitura,
  validarPayloadSincronizacao,
} = require('../sync');
const { criarPayloadEsp32 } = require('../esp32_payload');

function createEstufaRouter({
  simulador,
  db,
  authMiddleware,
  tokenConfigurado = false,
  buffer = null,
  modoReceptor = false,
}) {
  const router = express.Router();

  router.get('/status', async (_req, res) => {
    const dadosCompletos = simulador.lerCompleto();
    res.json(dadosCompletos);
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

    const resultado = simulador.sincronizarConfiguracao(configDoApp);
    try {
      await db.salvarComandoSync(configDoApp, resultado);
    } catch (error) {
      console.error('Falha ao salvar comando no banco:', error.message);
    }
    res.json(resultado);
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

    // Modo receptor: a leitura real do aparelho vira o estado servido em
    // /status (a nuvem reflete o hardware em vez de simular).
    if (modoReceptor) {
      simulador.aplicarStatusPersistido(status);
      simulador.aplicarConfiguracaoPersistida(req.body.config);
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
