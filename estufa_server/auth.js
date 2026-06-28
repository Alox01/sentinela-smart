const crypto = require('crypto');

function createAuthMiddleware(apiToken) {
  const token = (apiToken ?? '').trim();
  if (!token) {
    return (_req, _res, next) => next();
  }

  return (req, res, next) => {
    const tokenRecebido = extrairToken(req);

    if (tokensIguais(tokenRecebido, token)) {
      next();
      return;
    }

    res.status(401).json({
      erro: 'Nao autorizado',
      detalhe: 'Token ausente ou invalido.',
    });
  };
}

function extrairToken(req) {
  const authHeader = req.get('authorization') ?? '';
  if (authHeader.toLowerCase().startsWith('bearer ')) {
    return authHeader.substring('bearer '.length).trim();
  }

  return (req.get('x-device-token') ?? req.get('x-api-token') ?? '').trim();
}

function tokensIguais(recebido, esperado) {
  if (!recebido || recebido.length !== esperado.length) return false;

  return crypto.timingSafeEqual(
    Buffer.from(recebido),
    Buffer.from(esperado),
  );
}

module.exports = {
  createAuthMiddleware,
  extrairToken,
  tokensIguais,
};
