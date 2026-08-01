const express = require('express');

const { log } = require('../log');

// Quem recebe aviso: cadastro do token do celular por estufa, mais as duas
// rotas de teste. O que decide QUANDO avisar mora em `alertas_push.js`.
function criarRotasPush({ db, authMiddleware, push, alertas }) {
  const router = express.Router();

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
      log.erro('Falha ao registrar dispositivo push:', error.message);
      res.status(500).json({ erro: 'Falha ao registrar dispositivo' });
    }
  });

  // O celular diz quais estufas ele acompanha, e a nuvem descarta o resto das
  // inscricoes daquele token. E o conserto de orfaos: um DELETE perdido deixava
  // o vigia olhando aparelho que nao pertence a estufa nenhuma, sem nada indicar
  // isso. Fica na porteira comum de proposito - fala do celular, nao de um
  // aparelho, entao nao ha chave de aparelho a que amarrar.
  router.post('/push/dispositivos/sincronizar', authMiddleware, async (req, res) => {
    const tokenPush = (req.body?.tokenPush || '').trim();
    const idHardwares = req.body?.idHardwares;
    if (!tokenPush) {
      res.status(400).json({ erro: 'tokenPush obrigatorio' });
      return;
    }
    if (!Array.isArray(idHardwares)) {
      res.status(400).json({ erro: 'idHardwares deve ser uma lista' });
      return;
    }
    if (!db.reconciliarDispositivosPush) {
      res.json({ sucesso: true, removidas: 0, motivo: 'sem_persistencia' });
      return;
    }

    try {
      const { removidas } = await db.reconciliarDispositivosPush(
        tokenPush,
        idHardwares,
      );
      res.json({ sucesso: true, removidas });
    } catch (error) {
      log.erro('Falha ao reconciliar inscricoes push:', error.message);
      res.status(500).json({ erro: 'Falha ao reconciliar' });
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
      log.erro('Falha ao remover dispositivo push:', error.message);
      res.status(500).json({ erro: 'Falha ao remover dispositivo' });
    }
  });

  // Roda o watchdog na hora, sem esperar o ciclo. Serve para testar o aviso de
  // silencio sem precisar desligar a estufa e cronometrar 15 minutos.
  router.post('/push/verificar-silencio', authMiddleware, async (_req, res) => {
    if (!alertas.vigia) {
      res.status(503).json({ erro: 'Watchdog indisponivel' });
      return;
    }
    try {
      await alertas.vigia.verificar();
      res.json({ sucesso: true });
    } catch (error) {
      log.erro('Falha ao verificar silencio:', error.message);
      res.status(500).json({ erro: 'Falha ao verificar silencio' });
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
      log.erro('Falha no push de teste:', error.message);
      res.status(500).json({ erro: 'Falha ao enviar push de teste' });
    }
  });

  return router;
}

module.exports = {
  criarRotasPush,
};
