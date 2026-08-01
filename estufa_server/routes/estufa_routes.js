const express = require('express');

const { criarEstadoEstufa } = require('./estado_estufa');
const { criarAlertasPush } = require('./alertas_push');
const { criarRotasLeitura } = require('./rotas_leitura');
const { criarRotasComandos } = require('./rotas_comandos');
const { criarRotasAgendamentos } = require('./rotas_agendamentos');
const { criarRotasPush } = require('./rotas_push');
const { criarRotasChaves } = require('./rotas_chaves');

// Monta a API da estufa. Este arquivo nao tem regra de negocio: ele cria o
// estado que as rotas dividem, liga os avisos e pendura cada grupo de rotas.
// Cada grupo mora no seu proprio arquivo, para que "mexer no push" e "mexer no
// agendamento" deixem de ser a mesma edicao.
function createEstufaRouter({
  simulador,
  db,
  authMiddleware,
  // Porteira das acoes que MEXEM na estufa. Sem ela injetada, cai na comum - os
  // testes antigos e qualquer chamador que nao a passe seguem funcionando.
  authComando = null,
  tokenConfigurado = false,
  buffer = null,
  push = null,
  chavesAparelhos = null,
}) {
  const router = express.Router();
  const autorizarComando = authComando ?? authMiddleware;

  const estado = criarEstadoEstufa({ db, simulador });
  const alertas = criarAlertasPush({ db, push, estado });

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

  router.use(
    criarRotasLeitura({
      simulador,
      db,
      authMiddleware,
      autorizarComando,
      tokenConfigurado,
      buffer,
      estado,
      alertas,
    }),
  );
  router.use(
    criarRotasComandos({
      simulador,
      db,
      authMiddleware,
      autorizarComando,
      estado,
    }),
  );
  router.use(
    criarRotasAgendamentos({
      simulador,
      db,
      authMiddleware,
      autorizarComando,
      estado,
    }),
  );
  router.use(criarRotasPush({ db, authMiddleware, push, alertas }));
  router.use(criarRotasChaves({ db, authMiddleware, chavesAparelhos }));

  return router;
}

module.exports = {
  createEstufaRouter,
};
