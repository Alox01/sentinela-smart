const express = require('express');

const { iniciarAgendador, validarAgendamento } = require('../agendamentos');
const { log } = require('../log');
const { ID_SIMULADOR } = require('./estado_estufa');

// ---- Agendamentos de ajuste ----
// "As 14h deixe em 120 F" / "suba 10 F". O aviso ao produtor e um alarme local
// no celular (funciona sem internet); estas rotas cuidam apenas de TROCAR O
// ALVO na hora marcada, o que o celular nao consegue fazer com o app fechado.
// Vencido, o agendamento cai na mesma caixa de comandos de um ajuste manual.
function criarRotasAgendamentos({
  simulador,
  db,
  authMiddleware,
  autorizarComando,
  estado,
}) {
  const router = express.Router();

  // Aplica os agendamentos vencidos. Entram pela mesma caixa de comandos de um
  // ajuste feito a mao, entao o firmware nao precisou aprender nada novo: para
  // ele, um agendamento e indistinguivel de alguem mexendo no app naquela hora.
  const agendador = iniciarAgendador({
    listarAgendamentos: () =>
      db?.listarAgendamentos && db.estaHabilitado?.()
        ? db.listarAgendamentos()
        : [],
    // O alvo vigente resolve o "+10 F" no instante de aplicar, nao no de agendar.
    configDoAparelho: (idHardware) => estado.configVigente(idHardware),
    aplicarComando: (idHardware, comando) => {
      // O simulador nao busca a caixa de comandos - ele e servido do proprio
      // modelo, aqui dentro. Sem este desvio, um agendamento para ele ficava na
      // caixa para sempre: o aviso chegava e o ajuste nunca mudava, dando a
      // impressao de recurso quebrado justo na superficie feita para testar.
      if (!idHardware || idHardware === ID_SIMULADOR) {
        simulador.sincronizarConfiguracao(comando);
      } else {
        estado.guardarComandoPendente(idHardware, comando);
      }
      log.debug(
        `Agendamento aplicado (${idHardware}): ${JSON.stringify(comando)}`,
      );
    },
    remover: (id) => db?.removerAgendamento?.(id),
  });

  router.post('/agendamentos', autorizarComando, async (req, res) => {
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
      log.erro('Falha ao salvar agendamento:', error.message);
      res.status(500).json({ sucesso: false, erro: 'Falha ao salvar' });
    }
  });

  router.get('/agendamentos', autorizarComando, async (req, res) => {
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
      log.erro('Falha ao listar agendamentos:', error.message);
      res.status(500).json({ erro: 'Falha ao listar' });
    }
  });

  router.delete('/agendamentos/:id', autorizarComando, async (req, res) => {
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
      log.erro('Falha ao remover agendamento:', error.message);
      res.status(500).json({ sucesso: false, erro: 'Falha ao remover' });
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
      log.erro('Falha ao verificar agendamentos:', error.message);
      res.status(500).json({ erro: 'Falha ao verificar agendamentos' });
    }
  });

  return router;
}

module.exports = {
  criarRotasAgendamentos,
};
