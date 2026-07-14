const test = require('node:test');
const assert = require('node:assert/strict');
const { avaliarTokenApi } = require('../token_policy');

test('recusa token vazio ou ausente', () => {
  assert.equal(avaliarTokenApi('').ok, false);
  assert.equal(avaliarTokenApi('   ').ok, false);
  assert.equal(avaliarTokenApi(undefined).ok, false);
  assert.equal(avaliarTokenApi(null).ok, false);
});

test('recusa token curto demais', () => {
  const r = avaliarTokenApi('123456');
  assert.equal(r.ok, false);
  assert.match(r.motivo, /curto/i);
});

test('recusa token fraco/previsivel mesmo com tamanho ok', () => {
  assert.equal(avaliarTokenApi('12345678').ok, false);
  assert.equal(avaliarTokenApi('password').ok, false);
  assert.equal(avaliarTokenApi('sentinela').ok, false);
});

test('aceita token forte', () => {
  const r = avaliarTokenApi('Xk9-mQ2v-Lp7t');
  assert.equal(r.ok, true);
});

test('ignora espacos ao redor', () => {
  assert.equal(avaliarTokenApi('  Xk9-mQ2v-Lp7t  ').ok, true);
});
