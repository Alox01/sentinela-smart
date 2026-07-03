const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { reprocessarBuffer } = require('../persistencia');

function criarBufferFake(registrosIniciais = []) {
  const registros = [...registrosIniciais];
  return {
    registros,
    async listar() {
      return [...registros];
    },
    async remover(quantidade) {
      registros.splice(0, quantidade);
    },
  };
}

describe('reprocessarBuffer', () => {
  it('nao faz nada quando o buffer esta vazio', async () => {
    const buffer = criarBufferFake([]);
    const db = {
      async persistirLeituraBufferizada() {
        throw new Error('nao deve ser chamado');
      },
    };

    const enviadas = await reprocessarBuffer({ db, buffer });
    assert.equal(enviadas, 0);
  });

  it('reenvia todas as leituras em ordem e esvazia o buffer', async () => {
    const buffer = criarBufferFake([{ n: 1 }, { n: 2 }, { n: 3 }]);
    const recebidas = [];
    const db = {
      async persistirLeituraBufferizada(registro) {
        recebidas.push(registro.n);
        return true;
      },
    };

    const enviadas = await reprocessarBuffer({ db, buffer });

    assert.equal(enviadas, 3);
    assert.deepEqual(recebidas, [1, 2, 3]);
    assert.deepEqual(buffer.registros, []);
  });

  it('mantem no buffer as leituras ainda nao enviadas quando a nuvem cai no meio', async () => {
    const buffer = criarBufferFake([{ n: 1 }, { n: 2 }, { n: 3 }]);
    let chamadas = 0;
    const db = {
      async persistirLeituraBufferizada() {
        chamadas += 1;
        if (chamadas === 2) {
          throw new Error('nuvem indisponivel');
        }
        return true;
      },
    };

    await assert.rejects(() => reprocessarBuffer({ db, buffer }), /nuvem indisponivel/);

    // Apenas a primeira foi confirmada; as duas seguintes permanecem no buffer.
    assert.deepEqual(buffer.registros, [{ n: 2 }, { n: 3 }]);
  });
});
