const test = require('node:test');
const assert = require('node:assert/strict');
const { analisarEstado } = require('../logica');

test('dispara alerta quando sensor de chama esta ativo', () => {
  const resultado = analisarEstado(90, 90, 60, 60, 0, true);

  assert.equal(resultado.alertaIncendio, true);
  assert.equal(resultado.corStatus, 'red');
});

test('dispara alerta quando temperatura foge da tolerancia', () => {
  const resultado = analisarEstado(95, 90, 60, 60, 0, false);

  assert.equal(resultado.alertaIncendio, true);
  assert.match(resultado.aviso, /Temp Alta/i);
});

test('respeita silencio recente e desliga sirene', () => {
  const agora = Date.now();
  const resultado = analisarEstado(95, 90, 60, 60, agora, false);

  assert.equal(resultado.alertaIncendio, false);
});
