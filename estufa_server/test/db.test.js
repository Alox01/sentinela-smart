const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { __testables } = require('../db');

const {
  normalizarFonteLeitura,
  normalizarIpLocal,
  normalizarTipoDispositivo,
} = __testables;

describe('database device normalization', () => {
  it('treats the default simulator as simulator data', () => {
    assert.equal(
      normalizarTipoDispositivo({ idHardware: 'ESP32_REALISTIC_V2' }),
      'simulador',
    );
    assert.equal(
      normalizarFonteLeitura({ idHardware: 'ESP32_REALISTIC_V2' }),
      'simulador',
    );
  });

  it('treats unknown hardware ids as hardware data', () => {
    assert.equal(
      normalizarTipoDispositivo({ idHardware: 'ESP32_REAL_01' }),
      'hardware',
    );
    assert.equal(
      normalizarFonteLeitura({ idHardware: 'ESP32_REAL_01' }),
      'hardware',
    );
  });

  it('respects explicit source and device type values', () => {
    assert.equal(normalizarTipoDispositivo({ tipoDispositivo: 'simulador' }), 'simulador');
    assert.equal(normalizarTipoDispositivo({ tipo_dispositivo: 'hardware' }), 'hardware');
    assert.equal(normalizarFonteLeitura({ fonte: 'manual' }), 'manual');
  });

  it('preserves local device address when available', () => {
    assert.equal(normalizarIpLocal({ ip: '192.168.1.21' }), '192.168.1.21');
    assert.equal(normalizarIpLocal({ ipLocal: '192.168.1.50' }), '192.168.1.50');
    assert.equal(normalizarIpLocal({}), null);
  });
});
