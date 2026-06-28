const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { carregarEnvLocal } = require('../env');

test('carrega variaveis de arquivo env sem sobrescrever ambiente existente', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'estufa-env-'));
  const arquivo = path.join(dir, '.env');
  fs.writeFileSync(
    arquivo,
    [
      '# comentario',
      'ESTUFA_TESTE_TOKEN=abc123',
      'ESTUFA_TESTE_EXISTENTE=arquivo',
      'ESTUFA_TESTE_COM_ASPAS="valor com espaco"',
    ].join('\n'),
  );

  const antigoToken = process.env.ESTUFA_TESTE_TOKEN;
  const antigoExistente = process.env.ESTUFA_TESTE_EXISTENTE;
  const antigoComAspas = process.env.ESTUFA_TESTE_COM_ASPAS;

  try {
    delete process.env.ESTUFA_TESTE_TOKEN;
    process.env.ESTUFA_TESTE_EXISTENTE = 'ambiente';
    delete process.env.ESTUFA_TESTE_COM_ASPAS;

    carregarEnvLocal(arquivo);

    assert.equal(process.env.ESTUFA_TESTE_TOKEN, 'abc123');
    assert.equal(process.env.ESTUFA_TESTE_EXISTENTE, 'ambiente');
    assert.equal(process.env.ESTUFA_TESTE_COM_ASPAS, 'valor com espaco');
  } finally {
    restaurarEnv('ESTUFA_TESTE_TOKEN', antigoToken);
    restaurarEnv('ESTUFA_TESTE_EXISTENTE', antigoExistente);
    restaurarEnv('ESTUFA_TESTE_COM_ASPAS', antigoComAspas);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

function restaurarEnv(chave, valor) {
  if (valor === undefined) {
    delete process.env[chave];
  } else {
    process.env[chave] = valor;
  }
}
