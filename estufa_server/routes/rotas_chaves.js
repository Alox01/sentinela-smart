const express = require('express');

const { log } = require('../log');
const { extrairToken, tokensIguais } = require('../auth');

// ---- Chave por aparelho ----
// O primeiro registro e TOFU: ainda nao existe chave que possa autentica-lo.
// Exige que o cabecalho repita a chave do corpo para rejeitar requisicoes
// acidentais ou incompletas; o primeiro valor coerente para aquele id vence no
// banco. Com o id derivado dos 48 bits do MAC, ele nao e adivinhavel por uma
// varredura curta. A rotacao continua atras do authMiddleware e exige a chave
// anterior.
function criarRotasChaves({ db, authMiddleware, chavesAparelhos }) {
  const router = express.Router();

  router.post('/aparelhos/chave', async (req, res) => {
    const idHardware = (req.body?.idHardware || '').trim();
    const chave = (req.body?.chave || '').trim();
    if (!idHardware || !chave) {
      res.status(400).json({ erro: 'idHardware e chave obrigatorios' });
      return;
    }
    if (!tokensIguais(extrairToken(req), chave)) {
      res.status(401).json({ erro: 'A chave apresentada nao confere' });
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
      log.erro('Falha ao registrar chave do aparelho:', error.message);
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
      log.erro('Falha ao rotacionar chave do aparelho:', error.message);
      res.status(500).json({ erro: 'Falha ao rotacionar chave' });
    }
  });

  return router;
}

module.exports = {
  criarRotasChaves,
};
