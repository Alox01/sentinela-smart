const express = require('express');

const { validarPayloadLeitura } = require('../sync');
const { criarPayloadEsp32 } = require('../esp32_payload');
const { log } = require('../log');
const {
  criarRegistroLeitura,
  deveSalvarLeitura,
} = require('../storage_policy');
const { ID_SIMULADOR } = require('./estado_estufa');

// Tudo que e telemetria: o que o app le e o que o aparelho empurra.
function criarRotasLeitura({
  simulador,
  db,
  authMiddleware,
  autorizarComando,
  tokenConfigurado,
  buffer,
  estado,
  alertas,
}) {
  const router = express.Router();

  // Leituras tambem exigem token: telemetria da estufa e dado do produtor, nao
  // publico. O app ja envia a chave em toda chamada; o custo real e que uma
  // estufa cadastrada sem chave deixa de ler pela nuvem.
  router.get('/status', autorizarComando, async (req, res) => {
    const idHardware = req.query.idHardware;
    const dados = await estado.lerDispositivo(idHardware);
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

    const { config, aguardandoAparelho } = estado.configComPendente(
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
  router.get('/historico', autorizarComando, async (req, res) => {
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
      log.erro('Falha ao carregar historico:', error.message);
      res.status(500).json({ erro: 'Falha ao carregar historico' });
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
    const idHw = status.idHardware;
    if (idHw && idHw !== ID_SIMULADOR) {
      estado.registrarLeituraAoVivo(idHw, status, req.body.config);
      // A leitura que o aparelho empurra carrega a config dele: e por ela que
      // sabemos se o comando pendente ja foi obedecido.
      estado.limparPendentesConfirmados(idHw, req.body.config);
      // Avisa o produtor no celular quando um problema COMECA. Nao aguarda: a
      // resposta ao aparelho nao pode depender do FCM.
      alertas.avaliarAlertas(idHw, status, req.body.config).catch((error) =>
        log.erro('Falha ao avaliar alertas:', error.message),
      );
    }

    if (!db.estaHabilitado()) {
      res.json({ sucesso: true, persistido: false, motivo: 'persistencia_desabilitada' });
      return;
    }

    const agoraMs = Date.now();
    const registro = criarRegistroLeitura(status, dados.config, agoraMs);
    const decisao = deveSalvarLeitura({
      ultimaLeitura: estado.ultimaPersistida(idHw),
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
      estado.marcarPersistida(idHw, registro);
      res.json({
        sucesso: true,
        persistido: true,
        motivo: decisao.motivo,
      });
    } catch (error) {
      if (!buffer) {
        log.erro('Persistencia indisponivel:', error.message);
        res.status(503).json({
          sucesso: false,
          erro: 'Persistencia indisponivel',
        });
        return;
      }

      try {
        await buffer.adicionar(dados);
        estado.marcarPersistida(idHw, registro);
        res.json({
          sucesso: true,
          persistido: false,
          motivo: 'bufferizado',
          motivoAmostragem: decisao.motivo,
        });
      } catch (erroBuffer) {
        log.erro('Falha ao guardar leitura no buffer:', erroBuffer.message);
        res.status(500).json({
          sucesso: false,
          erro: 'Falha ao guardar leitura no buffer',
        });
      }
    }
  });

  return router;
}

module.exports = {
  criarRotasLeitura,
};
