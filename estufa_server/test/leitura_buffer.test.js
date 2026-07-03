const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

const { criarBufferLeituras } = require('../leitura_buffer');

describe('buffer offline de leituras', () => {
  let caminho;

  beforeEach(async () => {
    caminho = path.join(
      os.tmpdir(),
      `buffer_leituras_${process.pid}_${Math.random().toString(16).slice(2)}.jsonl`,
    );
  });

  afterEach(async () => {
    await fsp.rm(caminho, { force: true });
  });

  it('comeca vazio quando o arquivo nao existe', async () => {
    const buffer = criarBufferLeituras({ caminho });
    assert.equal(await buffer.tamanho(), 0);
    assert.deepEqual(await buffer.listar(), []);
  });

  it('adiciona e lista registros preservando a ordem', async () => {
    const buffer = criarBufferLeituras({ caminho });
    await buffer.adicionar({ status: { temperaturaAtual: 90 } });
    await buffer.adicionar({ status: { temperaturaAtual: 91 } });

    const registros = await buffer.listar();
    assert.equal(registros.length, 2);
    assert.equal(registros[0].status.temperaturaAtual, 90);
    assert.equal(registros[1].status.temperaturaAtual, 91);
  });

  it('remove os primeiros N registros', async () => {
    const buffer = criarBufferLeituras({ caminho });
    await buffer.adicionar({ n: 1 });
    await buffer.adicionar({ n: 2 });
    await buffer.adicionar({ n: 3 });

    await buffer.remover(2);

    const registros = await buffer.listar();
    assert.deepEqual(registros, [{ n: 3 }]);
  });

  it('apaga o arquivo quando todos os registros sao removidos', async () => {
    const buffer = criarBufferLeituras({ caminho });
    await buffer.adicionar({ n: 1 });
    await buffer.remover(1);

    assert.equal(await buffer.tamanho(), 0);
    await assert.rejects(() => fsp.access(caminho));
  });

  it('descarta as leituras mais antigas ao passar do limite', async () => {
    const buffer = criarBufferLeituras({ caminho, maxEntradas: 3 });
    for (let i = 1; i <= 5; i += 1) {
      await buffer.adicionar({ n: i });
    }

    const registros = await buffer.listar();
    assert.deepEqual(registros.map((r) => r.n), [3, 4, 5]);
  });

  it('ignora linha corrompida sem travar a leitura', async () => {
    const buffer = criarBufferLeituras({ caminho });
    await buffer.adicionar({ n: 1 });
    await fsp.appendFile(caminho, 'linha invalida\n', 'utf8');
    await buffer.adicionar({ n: 2 });

    const registros = await buffer.listar();
    assert.deepEqual(registros.map((r) => r.n), [1, 2]);
  });
});
