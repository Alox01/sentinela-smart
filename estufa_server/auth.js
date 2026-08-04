const crypto = require('crypto');

/// Id do aparelho de demonstracao. Duplicado de `routes/estado_estufa.js` de
/// proposito: a porteira nao pode depender das rotas, que dependem dela.
const ID_SIMULADOR = 'ESP32_REALISTIC_V2';
const { log } = require('./log');

// [chaveDoAparelho] permite autorizar uma requisicao pela chave DAQUELE aparelho,
// alem da chave global. Ela e consultada com o idHardware que a propria
// requisicao menciona, e esse detalhe e o ponto todo: a chave do aparelho A nao
// pode comandar o aparelho B. Sem essa amarracao, "chave por aparelho" nao
// separaria nada - qualquer chave registrada abriria qualquer estufa.
//
// A chave global continua valendo. Enquanto os aparelhos em campo nao tiverem
// registrado a sua, tirar a global deixaria o produtor sem acesso remoto a um
// sistema que funciona.
// [exigirChaveDoAparelho] separa as credenciais por ESTRAGO, nao por etapa.
//
// A chave universal fica compilada no firmware, entao ela nao e segredo: quem
// tiver o binario ou acesso a flash a extrai. Tratar como credencial seria
// mentira. Ela e um portao - barra varredura aleatoria da internet - e por isso
// so abre o que faz pouco estrago: o aparelho reportar leitura e registrar a
// propria chave.
//
// Registrar com ela e o que tira o beco sem saida: um aparelho que perde a chave
// propria ainda consegue voltar, em vez de ficar na rede funcionando e mudo para
// a nuvem, sem nada explicando.
//
// Mudar ajuste, silenciar sirene, agendar e ler a estufa exigem a chave DAQUELE
// aparelho. Quem extrair a universal consegue empurrar leitura falsa; nao
// consegue mexer na estufa de ninguem.
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

    // O simulador nao pede credencial nenhuma. Ele e uma DEMONSTRACAO: os
    // valores sao inventados pelo proprio servidor, nao ha estufa por tras, e
    // comandar so mexe na demonstracao. Exigir segredo para ver dado falso nao
    // protege nada e cobra o preco todo — foi o que impediu o produtor de
    // cadastrar o simulador sem decorar uma chave.
    //
    // Vale so para ESTE id. Os aparelhos reais seguem a regra de sempre.
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

    // A universal serve aqui quando a rota nao e de comando; e tambem quando o
    // aparelho AINDA nao registrou a sua, senao adotar esta separacao derrubaria
    // na hora todo aparelho que ainda nao passou pelo registro. Transitorio: cai
    // fora quando os aparelhos em campo tiverem a sua.
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
