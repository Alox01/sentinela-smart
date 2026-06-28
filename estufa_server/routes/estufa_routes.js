const express = require('express');

const { validarPayloadSincronizacao } = require('../sync');

function createEstufaRouter({ simulador, db, authMiddleware }) {
  const router = express.Router();

  router.get('/status', async (_req, res) => {
    const dadosCompletos = simulador.lerCompleto();
    try {
      await db.salvarSnapshot(dadosCompletos);
    } catch (error) {
      console.error('Falha ao salvar snapshot no banco:', error.message);
    }
    res.json(dadosCompletos);
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

  router.post('/debug/botao-fisico', authMiddleware, (req, res) => {
    const { tipo, valor } = req.body;
    simulador.simularBotaoFisico(tipo, valor);
    res.json({ msg: `Simulado botao fisico: ${tipo} -> ${valor}` });
  });

  return router;
}

module.exports = {
  createEstufaRouter,
};
