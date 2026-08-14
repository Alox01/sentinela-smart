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
  const resultado = analisarEstado(100, 90, 60, 60, 0, false);

  assert.equal(resultado.alarmeAtivo, true);
  assert.equal(resultado.alertaIncendio, true);
  assert.equal(resultado.perigoChama, false);
  assert.equal(resultado.riscoIncendio, false);
  assert.match(resultado.aviso, /Temperatura Alta/i);
});

// A margem daqui tem de ser a MESMA do firmware (margemF = 8). Estava em 5, e a
// divergencia aparecia na tela: 7 F de desvio acendia o LED em NUVEM e nao
// acendia em LOCAL, para a mesma estufa no mesmo instante.
test('7 F de desvio nao e alarme, como no aparelho', () => {
  const resultado = analisarEstado(97, 90, 60, 60, 0, false);

  assert.equal(resultado.alarmeAtivo, false);
  assert.equal(resultado.corStatus, 'green');
});

test('9 F de desvio ja e alarme, como no aparelho', () => {
  const resultado = analisarEstado(81, 90, 60, 60, 0, false);

  assert.equal(resultado.alarmeAtivo, true);
  assert.equal(resultado.corStatus, 'purple');
});

test('respeita silencio recente e desliga sirene', () => {
  const agora = Date.now();
  const resultado = analisarEstado(100, 90, 60, 60, agora, false);

  assert.equal(resultado.alarmeAtivo, false);
  assert.equal(resultado.alertaIncendio, false);
});


// A acomodacao existe para nao acusar problema enquanto a estufa persegue um
// alvo que o proprio produtor acabou de mudar.
test('acomodacao perdoa o desvio proporcional a mudanca do ajuste', () => {
  const agora = Date.now();
  // Subiu 10 graus: tolerancia vira 5 + 10 = 15, entao erro de 12 nao alarma.
  const r = analisarEstado(102, 90, 50, 50, 0, false, {
    desdeMs: agora,
    folga: 10,
  });
  assert.equal(r.alarmeAtivo, false);
});

test('acomodacao nao perdoa desvio maior do que a mudanca criou', () => {
  const agora = Date.now();
  // Mexeu 1 grau: tolerancia 6. Um desvio de 12 nao foi causado por isso.
  const r = analisarEstado(102, 90, 50, 50, 0, false, {
    desdeMs: agora,
    folga: 1,
  });
  assert.equal(r.alarmeAtivo, true);
});

test('a janela de acomodacao expira', () => {
  const r = analisarEstado(102, 90, 50, 50, 0, false, {
    desdeMs: Date.now() - 21 * 60 * 1000,
    folga: 10,
  });
  assert.equal(r.alarmeAtivo, true);
});

test('incendio nunca e acomodado', () => {
  const r = analisarEstado(200, 90, 50, 50, 0, false, {
    desdeMs: Date.now(),
    folga: 20,
  });
  assert.equal(r.alarmeAtivo, true);
  assert.equal(r.riscoIncendio, true);
});

test('sem acomodacao o comportamento antigo vale', () => {
  const r = analisarEstado(102, 90, 50, 50, 0, false);
  assert.equal(r.alarmeAtivo, true);
});
