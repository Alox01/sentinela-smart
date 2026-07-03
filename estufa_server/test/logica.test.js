const test = require('node:test');
const assert = require('node:assert/strict');
const { analisarEstado } = require('../logica');

test('dispara alerta critico quando sensor de chama esta ativo', () => {
  const resultado = analisarEstado(90, 90, 60, 60, 0, true);

  assert.equal(resultado.alarmeAtivo, true);
  assert.equal(resultado.alertaIncendio, true);
  assert.equal(resultado.perigoChama, true);
  assert.equal(resultado.riscoIncendio, false);
  assert.equal(resultado.corStatus, 'red');
});

test('dispara risco de incendio quando temperatura passa do limite seguro', () => {
  const resultado = analisarEstado(176, 150, 60, 60, 0, false);

  assert.equal(resultado.alarmeAtivo, true);
  assert.equal(resultado.alertaIncendio, true);
  assert.equal(resultado.perigoChama, false);
  assert.equal(resultado.riscoIncendio, true);
  assert.equal(resultado.corStatus, 'red');
});

test('dispara alarme de processo quando temperatura foge da tolerancia', () => {
  const resultado = analisarEstado(95, 90, 60, 60, 0, false);

  assert.equal(resultado.alarmeAtivo, true);
  assert.equal(resultado.alertaIncendio, true);
  assert.equal(resultado.perigoChama, false);
  assert.equal(resultado.riscoIncendio, false);
  assert.match(resultado.aviso, /Temperatura Alta/i);
});

test('respeita silencio recente e desliga sirene', () => {
  const agora = Date.now();
  const resultado = analisarEstado(95, 90, 60, 60, agora, false);

  assert.equal(resultado.alarmeAtivo, false);
  assert.equal(resultado.alertaIncendio, false);
});

