const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  iniciarRetencao,
  lerDiasRetencao,
  RETENCAO_PADRAO_DIAS,
} = require('../retention_scheduler');

describe('lerDiasRetencao', () => {
  it('usa o padrao quando ausente ou invalido', () => {
    assert.equal(lerDiasRetencao(undefined), RETENCAO_PADRAO_DIAS);
    assert.equal(lerDiasRetencao(''), RETENCAO_PADRAO_DIAS);
    assert.equal(lerDiasRetencao('abc'), RETENCAO_PADRAO_DIAS);
    assert.equal(lerDiasRetencao('0'), RETENCAO_PADRAO_DIAS);
  });

  it('aceita um valor valido', () => {
    assert.equal(lerDiasRetencao('90'), 90);
  });
});

describe('iniciarRetencao', () => {
  it('nao faz nada sem banco habilitado', () => {
    let chamou = false;
    const timer = iniciarRetencao({
      db: { estaHabilitado: () => false, apagarLeiturasAntigas: async () => { chamou = true; } },
    });
    assert.equal(timer, null);
    assert.equal(chamou, false);
  });

  it('limpa no boot passando a janela configurada', async () => {
    const chamadas = [];
    iniciarRetencao({
      db: {
        estaHabilitado: () => true,
        apagarLeiturasAntigas: async (dias) => {
          chamadas.push(dias);
          return { apagadas: 3 };
        },
      },
      diasRetencao: 120,
      setIntervalFn: () => ({ unref() {} }),
    });
    await new Promise((r) => setImmediate(r));
    assert.deepEqual(chamadas, [120]);
  });

  it('uma falha na limpeza nao propaga (nao derruba o servidor)', async () => {
    assert.doesNotThrow(() => {
      iniciarRetencao({
        db: {
          estaHabilitado: () => true,
          apagarLeiturasAntigas: async () => {
            throw new Error('banco fora');
          },
        },
        diasRetencao: 30,
        setIntervalFn: () => ({ unref() {} }),
        logger: { error() {}, log() {} },
      });
    });
    await new Promise((r) => setImmediate(r));
  });
});
