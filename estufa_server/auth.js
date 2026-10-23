const crypto = require('crypto');

// Identificador do simulador. Mantido localmente para evitar dependência das rotas.
const ID_SIMULADOR = 'ESP32_REALISTIC_V2';
const { log } = require('./log');

// Autoriza pela chave vinculada ao idHardware. A chave global permanece apenas
// para compatibilidade e rotas de baixo impacto; comandos exigem a chave própria.
function createAuthMiddleware(
  apiToken,
  { chaveDoAparelho, exigirChaveDoAparelho = false } = {},
) {
  const token = (apiToken ?? '').trim();
  if (!token && !chaveDoAparelho) {
    return (_req, _res, next) => next();
  }

  return async (req, res, next) => {
    const tokenRecebido = extrairToken(req);
    const idHardware = idHardwareDaRequisicao(req);

    // O simulador não representa um aparelho físico e dispensa autenticação.
    if (idHardware === ID_SIMULADOR) {
      next();
      return;
    }

    let chaveRegistrada = null;

    if (tokenRecebido && chaveDoAparelho && idHardware) {
      try {
        chaveRegistrada = await chaveDoAparelho(idHardware);
        if (chaveRegistrada && tokensIguais(tokenRecebido, chaveRegistrada)) {
          next();
          return;
        }
      } catch (error) {
        // Falha ao resolver a chave nao autoriza: nega, e o aparelho repete.
        log.erro('Falha ao verificar chave do aparelho:', error.message);
        res.status(503).json({ erro: 'Indisponivel' });
        return;
      }
    }

    // Mantém compatibilidade com aparelhos que ainda não registraram chave própria.
    const universalBasta = !exigirChaveDoAparelho || chaveRegistrada == null;
    if (universalBasta && token && tokensIguais(tokenRecebido, token)) {
      next();
      return;
    }

    res.status(401).json({
      erro: 'Nao autorizado',
      detalhe: exigirChaveDoAparelho
        ? 'Esta acao exige a chave do aparelho.'
        : 'Token ausente ou invalido.',
    });
  };
}

// De onde o idHardware aparece nas rotas: query (`/status?idHardware=`), corpo
// direto (`/leitura`, `/push/dispositivos`) e corpo aninhado em status (formato
// do payload completo do aparelho).
function idHardwareDaRequisicao(req) {
  const candidatos = [
    req.query?.idHardware,
    req.body?.idHardware,
    req.body?.status?.idHardware,
  ];
  for (const candidato of candidatos) {
    if (typeof candidato === 'string' && candidato.trim() !== '') {
      return candidato.trim();
    }
  }
  return null;
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
  ID_SIMULADOR,
  idHardwareDaRequisicao,
  extrairToken,
  tokensIguais,
};
