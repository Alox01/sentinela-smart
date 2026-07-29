// Chaves por aparelho, em memoria, para o middleware nao consultar o banco a
// cada requisicao. O banco continua sendo a verdade; isto e so o atalho.
//
// Por que existir: hoje uma chave global autoriza comandar TODOS os aparelhos,
// entao uma chave vazada entrega a propriedade inteira. Com chave por aparelho,
// o estrago para no aparelho cuja chave vazou - e, de brinde, cada chave e
// aleatoria e unica em vez de escolhida (e repetida) pelo produtor.

const TEMPO_CACHE_MS = 60 * 1000;

function criarRegistroDeChaves({ db, agora = () => Date.now() } = {}) {
  let cache = new Map();
  let carregadoEmMs = 0;
  let carregando = null;

  async function recarregar() {
    if (!db?.carregarChavesAparelhos) return cache;
    // Uma recarga por vez: varias requisicoes chegando juntas depois do cache
    // vencer nao viram varias consultas.
    carregando ??= (async () => {
      try {
        cache = await db.carregarChavesAparelhos();
        carregadoEmMs = agora();
      } catch (error) {
        // Falha ao ler nao pode virar "aparelho sem chave", que liberaria o
        // registro TOFU de um aparelho que ja tem dono. Mantem o cache anterior.
        console.error('Falha ao carregar chaves de aparelhos:', error.message);
      } finally {
        carregando = null;
      }
      return cache;
    })();
    return carregando;
  }

  async function chaveDe(idHardware) {
    if (!idHardware) return null;
    if (agora() - carregadoEmMs > TEMPO_CACHE_MS) await recarregar();
    return cache.get(idHardware) ?? null;
  }

  // Chamada depois de registrar ou rotacionar: sem isto, a chave nova so passaria
  // a valer quando o cache vencesse, e o aparelho levaria 401 nesse meio-tempo.
  function anotar(idHardware, chave) {
    if (!idHardware || !chave) return;
    cache.set(idHardware, chave);
  }

  function esquecer(idHardware) {
    cache.delete(idHardware);
  }

  return { chaveDe, anotar, esquecer, recarregar };
}

module.exports = { criarRegistroDeChaves, TEMPO_CACHE_MS };
