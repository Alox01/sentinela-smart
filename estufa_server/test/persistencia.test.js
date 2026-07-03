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
    const enviadas = await reprocessarBuffer({
      buffer,
      enviar() {
        throw new Error('nao deve ser chamado');
      },
    });
    assert.equal(enviadas, 0);
  });

  it('reenvia todas as leituras em ordem e esvazia o buffer', async () => {
    const buffer = criarBufferFake([{ n: 1 }, { n: 2 }, { n: 3 }]);
    const recebidas = [];

    const enviadas = await reprocessarBuffer({
      buffer,
      async enviar(registro) {
        recebidas.push(registro.n);
      },
    });

    assert.equal(enviadas, 3);
    assert.deepEqual(recebidas, [1, 2, 3]);
    assert.deepEqual(buffer.registros, []);
  });

  it('mantem no buffer as leituras ainda nao enviadas quando o destino cai no meio', async () => {
    const buffer = criarBufferFake([{ n: 1 }, { n: 2 }, { n: 3 }]);
    let chamadas = 0;

    await assert.rejects(
      () =>
        reprocessarBuffer({
          buffer,
          async enviar() {
            chamadas += 1;
            if (chamadas === 2) {
              throw new Error('destino indisponivel');
            }
          },
        }),
      /destino indisponivel/,
    );

    // Apenas a primeira foi confirmada; as duas seguintes permanecem no buffer.
    assert.deepEqual(buffer.registros, [{ n: 2 }, { n: 3 }]);
  });
});
