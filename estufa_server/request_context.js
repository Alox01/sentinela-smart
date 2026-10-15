const crypto = require('crypto');

// Identifica cada resposta sem confiar em um valor enviado pela internet. O id
// aparece no cabecalho e nos logs; assim um erro visto no celular pode ser
// localizado sem registrar token, corpo da requisicao ou dado do produtor.
function criarContextoRequisicao({ gerarId = crypto.randomUUID, agora = Date.now, log } = {}) {
  return (req, res, next) => {
    const id = gerarId();
    const inicio = agora();
    req.id = id;
    res.setHeader('X-Request-Id', id);

    res.on('finish', () => {
      if (!log) return;
      const registro =
        `[${id}] ${req.method} ${req.path} -> ${res.statusCode} (${agora() - inicio}ms)`;
      if (res.statusCode >= 500) log.erro(registro);
      else if (res.statusCode >= 400) log.info(registro);
      else log.debug(registro);
    });
    next();
  };
}

module.exports = { criarContextoRequisicao };
