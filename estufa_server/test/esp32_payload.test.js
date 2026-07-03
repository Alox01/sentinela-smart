const test = require('node:test');
const assert = require('node:assert/strict');

const { criarPayloadEsp32 } = require('../esp32_payload');

test('converte leitura do simulador para formato simples do ESP32', () => {
  const payload = criarPayloadEsp32({
    status: {
      temperaturaAtual: 95.24,
      umidadeAtual: 64.76,
      alarmeAtivo: true,
      perigoChama: false,
      riscoIncendio: false,
      aquecedorLigado: true,
      umidificadorLigado: false,
    },
    config: {
      temperaturaMeta: 96,
      umidadeMeta: 65,
      modoSilencioso: false,
    },
  }, 'localhost');

  assert.deepEqual(payload, {
    temperaturaF: 95.2,
    umidade: 64.8,
    temperaturaAlvoF: 96,
    umidadeAlvo: 65,
    margemF: 5,
    alertaTemperatura: true,
    alertaLuz: false,
    mostrandoUmidade: false,
    modoAjuste: false,
    buzzerSilenciado: false,
    ledControleLigado: true,
    leituraOk: true,
    ip: 'localhost',
    tokenConfigurado: false,
    versaoFirmware: 'simulador-http-v1',
  });
});
