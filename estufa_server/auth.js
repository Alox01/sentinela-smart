const crypto = require('crypto');

// [chaveDoAparelho] permite autorizar uma requisicao pela chave DAQUELE aparelho,
// alem da chave global. Ela e consultada com o idHardware que a propria
// requisicao menciona, e esse detalhe e o ponto todo: a chave do aparelho A nao
// pode comandar o aparelho B. Sem essa amarracao, "chave por aparelho" nao
// separaria nada - qualquer chave registrada abriria qualquer estufa.
//
// A chave global continua valendo. Enquanto os aparelhos em campo nao tiverem
// registrado a sua, tirar a global deixaria o produtor sem acesso remoto a um
// sistema que funciona.
function createAuthMiddleware(apiToken, { chaveDoAparelho } = {}) {
  const token = (apiToken ?? '').trim();
  if (!token && !chaveDoAparelho) {
    return (_req, _res, next) => next();
  }

  return async (req, res, next) => {
    const tokenRecebido = extrairToken(req);

    if (token && tokensIguais(tokenRecebido, token)) {
      next();
      return;
    }

    if (tokenRecebido && chaveDoAparelho) {
      const idHardware = idHardwareDaRequisicao(req);
      if (idHardware) {
        try {
          const chave = await chaveDoAparelho(idHardware);
          if (chave && tokensIguais(tokenRecebido, chave)) {
            next();
            return;
          }
        } catch (error) {
          // Falha ao resolver a chave nao autoriza: nega, e o aparelho repete.
          console.error('Falha ao verificar chave do aparelho:', error.message);
        }
      }
    }

    res.status(401).json({
      erro: 'Nao autorizado',
      detalhe: 'Token ausente ou invalido.',
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
  idHardwareDaRequisicao,
  extrairToken,
  tokensIguais,
};
