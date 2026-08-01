const express = require('express');

const {
  validarPayloadBotaoFisico,
  validarPayloadSincronizacao,
} = require('../sync');
const { log } = require('../log');
const { ID_SIMULADOR } = require('./estado_estufa');

// O caminho de ida: o que o app pede e o que o aparelho vem buscar.
function criarRotasComandos({
  simulador,
  db,
  authMiddleware,
  autorizarComando,
  estado,
}) {
  const router = express.Router();

  router.post('/sincronizar', autorizarComando, async (req, res) => {
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
      estado.guardarComandoPendente(idHardware, comando);

      const resultado = {
        sucesso: true,
        pendente: true,
        idHardware,
        aviso: 'Comando guardado; sera aplicado quando o aparelho buscar.',
      };
      try {
        await db.salvarComandoSync(configDoApp, resultado);
      } catch (error) {
        log.erro('Falha ao salvar comando no banco:', error.message);
      }
      res.json(resultado);
      return;
    }

    const resultado = simulador.sincronizarConfiguracao(configDoApp);
    try {
      await db.salvarComandoSync(configDoApp, resultado);
    } catch (error) {
      log.erro('Falha ao salvar comando no banco:', error.message);
    }
    res.json(resultado);
  });

  // O aparelho pergunta se tem ajuste esperando por ele. Responder e entregar:
  // o proprio POST /leitura seguinte, ja com a config nova, serve de confirmacao
  // â€” e se o comando se perder no caminho, o app reenvia pela fila que ja tem.
  router.get('/comandos', autorizarComando, (req, res) => {
    const idHardware = req.query.idHardware;
    if (!idHardware) {
      res.status(400).json({ erro: 'idHardware obrigatorio' });
      return;
    }

    res.json({ idHardware, comando: estado.comandoPendente(idHardware) });
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
      log.erro('Falha ao salvar ajuste fisico no banco:', error.message);
    }
    res.json({ msg: `Simulado botao fisico: ${tipo} -> ${valor}` });
  });

  return router;
}

module.exports = {
  criarRotasComandos,
};
