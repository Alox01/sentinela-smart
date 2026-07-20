const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { decidirAviso, iniciarWatchdog } = require('../watchdog');

const MIN = 60 * 1000;

describe('decidirAviso', () => {
  const base = { agoraMs: 100 * MIN, limiteMs: 15 * MIN };

  it('avisa quando o silencio passa do limite', () => {
    const d = decidirAviso({ ...base, ultimoContatoMs: 80 * MIN });
    assert.equal(d, 'silencio');
  });

  it('nao repete enquanto o silencio dura', () => {
    const d = decidirAviso({
      ...base,
      ultimoContatoMs: 80 * MIN,
      estavaSilencioso: true,
    });
    assert.equal(d, null);
  });

  it('avisa o retorno quando volta a reportar', () => {
    const d = decidirAviso({
      ...base,
      ultimoContatoMs: 99 * MIN,
      estavaSilencioso: true,
    });
    assert.equal(d, 'retorno');
  });

  it('cala enquanto o aparelho reporta normalmente', () => {
    assert.equal(decidirAviso({ ...base, ultimoContatoMs: 99 * MIN }), null);
  });

  it('aparelho sem leitura nenhuma nao gera alarme falso', () => {
    // Pode nunca ter sido ligado: silencio aqui nao prova nada.
    assert.equal(decidirAviso({ ...base, ultimoContatoMs: 0 }), null);
    assert.equal(decidirAviso({ ...base, ultimoContatoMs: undefined }), null);
  });
});

describe('iniciarWatchdog', () => {
  const semTimer = () => ({ unref() {} });

  it('avisa uma vez na entrada do silencio e uma vez no retorno', async () => {
    let ultimoContatoMs = 0;
    let agoraMs = 100 * MIN;
    const avisos = [];

    const vigia = iniciarWatchdog({
      listarAparelhos: async () => [
        { idHardware: 'ESP32_X', ultimoContatoMs },
      ],
      notificar: async (a) => avisos.push(a),
      setIntervalFn: semTimer,
      agora: () => agoraMs,
      limiteMs: 15 * MIN,
    });

    // Silencioso ha 20 min -> avisa.
    ultimoContatoMs = 80 * MIN;
    await vigia.verificar();
    assert.equal(avisos.length, 1);
    assert.equal(avisos[0].evento, 'semComunicacao');
    assert.equal(avisos[0].critico, true);
    assert.match(avisos[0].corpo, /energia|internet/);

    // Continua em silencio -> nao repete.
    await vigia.verificar();
    assert.equal(avisos.length, 1);

    // Voltou a reportar -> avisa o retorno, e nao critico.
    ultimoContatoMs = agoraMs;
    await vigia.verificar();
    assert.equal(avisos.length, 2);
    assert.equal(avisos[1].critico, false);

    // E nao fica repetindo o retorno.
    await vigia.verificar();
    assert.equal(avisos.length, 2);
  });

  it('uma falha ao listar nao derruba o vigia', async () => {
    const vigia = iniciarWatchdog({
      listarAparelhos: async () => {
        throw new Error('banco fora');
      },
      notificar: async () => {},
      setIntervalFn: semTimer,
      logger: { error() {} },
    });
    await assert.doesNotReject(() => vigia.verificar());
  });
});
