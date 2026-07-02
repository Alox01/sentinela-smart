const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createCorsOptions,
  parseAllowedOrigins,
} = require('../security');

test('parseia origens permitidas separadas por virgula', () => {
  assert.deepEqual(
    parseAllowedOrigins('http://localhost:53312, https://app.exemplo.com '),
    ['http://localhost:53312', 'https://app.exemplo.com'],
  );
});

test('mantem CORS aberto quando nenhuma origem foi configurada', () => {
  assert.deepEqual(createCorsOptions(''), {});
});

test('aceita somente origens configuradas quando CORS esta restrito', async () => {
  const options = createCorsOptions('http://localhost:53312');

  const aceito = await executarOrigem(options, 'http://localhost:53312');
  const rejeitado = await executarOrigem(options, 'http://malicioso.local');

  assert.equal(aceito, true);
  assert.match(rejeitado.message, /Origem nao permitida/);
});

function executarOrigem(options, origin) {
  return new Promise((resolve) => {
    options.origin(origin, (error, allowed) => {
      resolve(error ?? allowed);
    });
  });
}
