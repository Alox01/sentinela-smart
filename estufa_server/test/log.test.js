const test = require('node:test');
const assert = require('node:assert');
const { criarLog, nivelConfigurado, PADRAO } = require('../log');

function saidaFalsa() {
  const linhas = { log: [], error: [] };
  return {
    linhas,
    log: (...a) => linhas.log.push(a.join(' ')),
    error: (...a) => linhas.error.push(a.join(' ')),
  };
}

test('nivel invalido ou ausente cai no padrao', () => {
  assert.equal(nivelConfigurado(undefined), PADRAO);
  assert.equal(nivelConfigurado(''), PADRAO);
  assert.equal(nivelConfigurado('barulhento'), PADRAO);
});

test('nivel e lido sem depender de espaco ou maiuscula', () => {
  assert.equal(nivelConfigurado('  ERRO '), 'erro');
});

// O caso que motivou tudo: o simulador narra cada ciclo, e em producao essa
// narracao esconde o erro de verdade no meio.
test('em erro, so o erro passa', () => {
  const saida = saidaFalsa();
  const log = criarLog({ nivel: 'erro', saida });
  log.debug('clima mudou');
  log.info('servidor subiu');
  log.erro('falhou');
  assert.deepEqual(saida.linhas.log, []);
  assert.deepEqual(saida.linhas.error, ['falhou']);
});

test('em info, a narracao de ciclo fica de fora', () => {
  const saida = saidaFalsa();
  const log = criarLog({ nivel: 'info', saida });
  log.debug('clima mudou');
  log.info('servidor subiu');
  assert.deepEqual(saida.linhas.log, ['servidor subiu']);
});

test('em debug, tudo passa', () => {
  const saida = saidaFalsa();
  const log = criarLog({ nivel: 'debug', saida });
  log.debug('clima mudou');
  log.info('servidor subiu');
  log.erro('falhou');
  assert.equal(saida.linhas.log.length, 2);
  assert.equal(saida.linhas.error.length, 1);
});

// Silencioso existe para o teste nao poluir a saida - e cala ate o erro.
test('silencioso cala inclusive o erro', () => {
  const saida = saidaFalsa();
  const log = criarLog({ nivel: 'silencioso', saida });
  log.erro('falhou');
  assert.deepEqual(saida.linhas.error, []);
});
