const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { criarEnviadorPush, lerCredencial } = require('../push');

const CREDENCIAL_FALSA = {
  project_id: 'projeto-teste',
  private_key: '-----BEGIN PRIVATE KEY-----abc-----END PRIVATE KEY-----',
  client_email: 'x@y.iam.gserviceaccount.com',
};

describe('lerCredencial', () => {
  it('aceita o JSON cru', () => {
    const c = lerCredencial({
      FIREBASE_SERVICE_ACCOUNT: JSON.stringify(CREDENCIAL_FALSA),
    });
    assert.equal(c.project_id, 'projeto-teste');
  });

  it('aceita base64 (facilita colar no painel do Render)', () => {
    const b64 = Buffer.from(JSON.stringify(CREDENCIAL_FALSA)).toString('base64');
    const c = lerCredencial({ FIREBASE_SERVICE_ACCOUNT: b64 });
    assert.equal(c.project_id, 'projeto-teste');
  });

  it('devolve null quando ausente, invalido ou incompleto', () => {
    assert.equal(lerCredencial({}), null);
    assert.equal(lerCredencial({ FIREBASE_SERVICE_ACCOUNT: '   ' }), null);
    assert.equal(lerCredencial({ FIREBASE_SERVICE_ACCOUNT: 'nao-e-json' }), null);
    // Sem private_key nao da para assinar: melhor desabilitar do que quebrar.
    assert.equal(
      lerCredencial({
        FIREBASE_SERVICE_ACCOUNT: JSON.stringify({ project_id: 'x' }),
      }),
      null,
    );
  });
});

describe('criarEnviadorPush sem credencial', () => {
  it('fica desabilitado e nao quebra o servidor', async () => {
    const enviador = criarEnviadorPush({
      env: {},
      logger: { log() {}, error() {} },
    });
    assert.equal(enviador.habilitado, false);
    // Enviar continua seguro de chamar: vira no-op.
    const r = await enviador.enviar({ tokens: ['a'], titulo: 't', corpo: 'c' });
    assert.equal(r.enviados, 0);
    assert.deepEqual(r.invalidos, []);
  });
});
