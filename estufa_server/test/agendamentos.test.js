const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  estaDevido,
  iniciarAgendador,
  resolverComando,
  validarAgendamento,
} = require('../agendamentos');

const AGORA = 1800000000000; // instante fixo: os testes nao dependem do relogio

describe('estaDevido', () => {
  it('vence quando a hora chega ou passa', () => {
    assert.equal(estaDevido({ aplicarEmMs: AGORA }, AGORA), true);
    assert.equal(estaDevido({ aplicarEmMs: AGORA - 1000 }, AGORA), true);
  });

  it('nao vence antes da hora', () => {
    assert.equal(estaDevido({ aplicarEmMs: AGORA + 1000 }, AGORA), false);
  });

  it('ignora agendamento sem hora valida', () => {
    assert.equal(estaDevido({}, AGORA), false);
    assert.equal(estaDevido({ aplicarEmMs: 0 }, AGORA), false);
    assert.equal(estaDevido({ aplicarEmMs: 'amanha' }, AGORA), false);
  });
});

describe('resolverComando', () => {
  it('valor absoluto vai direto, com o timestamp do LWW', () => {
    const comando = resolverComando(
      { temperaturaMeta: 120 },
      { temperaturaMeta: 100 },
      AGORA,
    );
    assert.equal(comando.temperaturaMeta, 120);
    assert.equal(comando.tempTimestamp, AGORA);
  });

  // O ponto central do relativo: "+10" e sobre o alvo de AGORA, nao o de quando
  // o produtor agendou. Ele pode ter mexido na estufa nesse meio tempo.
  it('valor relativo parte do alvo vigente', () => {
    const comando = resolverComando(
      { temperaturaDelta: 10 },
      { temperaturaMeta: 135 },
      AGORA,
    );
    assert.equal(comando.temperaturaMeta, 145);
  });

  it('relativo negativo desce o alvo', () => {
    const comando = resolverComando(
      { temperaturaDelta: -15 },
      { temperaturaMeta: 135 },
      AGORA,
    );
    assert.equal(comando.temperaturaMeta, 120);
  });

  // Prende na borda em vez de recusar: o produtor pediu "o mais quente que der".
  it('relativo que estoura o limite para no maximo', () => {
    const comando = resolverComando(
      { temperaturaDelta: 30 },
      { temperaturaMeta: 195 },
      AGORA,
    );
    assert.equal(comando.temperaturaMeta, 200);
  });

  it('umidade tambem aceita absoluto e relativo', () => {
    assert.equal(
      resolverComando({ umidadeMeta: 40 }, { umidadeMeta: 90 }, AGORA)
        .umidadeMeta,
      40,
    );
    const relativo = resolverComando(
      { umidadeDelta: -20 },
      { umidadeMeta: 90 },
      AGORA,
    );
    assert.equal(relativo.umidadeMeta, 70);
    assert.equal(relativo.umidTimestamp, AGORA);
  });

  // Sem saber de quanto partir, um "+10" nao tem resposta certa - e chutar
  // mexeria na estufa errado. Devolve null para o agendador tentar depois.
  it('relativo sem alvo conhecido nao resolve', () => {
    assert.equal(resolverComando({ temperaturaDelta: 10 }, undefined, AGORA), null);
    assert.equal(resolverComando({ temperaturaDelta: 10 }, {}, AGORA), null);
  });

  it('agendamento sem nada aplicavel devolve null', () => {
    assert.equal(resolverComando({}, { temperaturaMeta: 100 }, AGORA), null);
  });

  it('temperatura e umidade juntas no mesmo comando', () => {
    const comando = resolverComando(
      { temperaturaMeta: 120, umidadeDelta: -10 },
      { temperaturaMeta: 100, umidadeMeta: 80 },
      AGORA,
    );
    assert.equal(comando.temperaturaMeta, 120);
    assert.equal(comando.umidadeMeta, 70);
  });
});

describe('validarAgendamento', () => {
  const valido = {
    idHardware: 'ESP32_ABC123',
    aplicarEmMs: AGORA + 2 * 60 * 60 * 1000,
    temperaturaMeta: 120,
  };

  it('aceita um agendamento bem formado', () => {
    assert.equal(validarAgendamento(valido, AGORA).valido, true);
  });

  it('exige idHardware', () => {
    const r = validarAgendamento({ ...valido, idHardware: '' }, AGORA);
    assert.equal(r.valido, false);
  });

  it('recusa hora no passado', () => {
    const r = validarAgendamento(
      { ...valido, aplicarEmMs: AGORA - 10 * 60 * 1000 },
      AGORA,
    );
    assert.equal(r.valido, false);
  });

  // Os relogios do celular e do servidor nunca batem exatamente; recusar por
  // segundos de diferenca seria arbitrario.
  it('tolera um minuto de folga no relogio', () => {
    const r = validarAgendamento(
      { ...valido, aplicarEmMs: AGORA - 30 * 1000 },
      AGORA,
    );
    assert.equal(r.valido, true);
  });

  it('exige pelo menos temperatura ou umidade', () => {
    const r = validarAgendamento(
      { idHardware: 'x', aplicarEmMs: AGORA + 1000 },
      AGORA,
    );
    assert.equal(r.valido, false);
  });

  it('recusa valor e variacao do mesmo campo', () => {
    const r = validarAgendamento(
      { ...valido, temperaturaDelta: 5 },
      AGORA,
    );
    assert.equal(r.valido, false);
  });

  it('recusa temperatura fora dos limites', () => {
    assert.equal(
      validarAgendamento({ ...valido, temperaturaMeta: 250 }, AGORA).valido,
      false,
    );
    assert.equal(
      validarAgendamento({ ...valido, temperaturaMeta: 10 }, AGORA).valido,
      false,
    );
  });

  it('recusa variacao que nao e numero', () => {
    const r = validarAgendamento(
      { idHardware: 'x', aplicarEmMs: AGORA + 1000, temperaturaDelta: 'muito' },
      AGORA,
    );
    assert.equal(r.valido, false);
  });
});

describe('iniciarAgendador', () => {
  function montar({ agendamentos, config }) {
    const aplicados = [];
    const removidos = [];
    const agendador = iniciarAgendador({
      listarAgendamentos: () => agendamentos,
      configDoAparelho: () => config,
      aplicarComando: (idHardware, comando) =>
        aplicados.push({ idHardware, comando }),
      remover: (id) => removidos.push(id),
      setIntervalFn: () => null, // sem timer: o teste chama verificar() na mao
      agora: () => AGORA,
      logger: { error() {} },
    });
    return { agendador, aplicados, removidos };
  }

  it('aplica o que venceu e nao toca no que falta', async () => {
    const { agendador, aplicados, removidos } = montar({
      agendamentos: [
        { id: '1', idHardware: 'A', aplicarEmMs: AGORA - 1000, temperaturaMeta: 120 },
        { id: '2', idHardware: 'B', aplicarEmMs: AGORA + 60000, temperaturaMeta: 130 },
      ],
      config: { temperaturaMeta: 100 },
    });

    await agendador.verificar();

    assert.equal(aplicados.length, 1);
    assert.equal(aplicados[0].idHardware, 'A');
    assert.equal(aplicados[0].comando.temperaturaMeta, 120);
    assert.deepEqual(removidos, ['1']);
  });

  // Sem alvo conhecido o relativo fica na fila: some so quando for aplicado.
  it('mantem o relativo pendente enquanto o alvo e desconhecido', async () => {
    const { agendador, aplicados, removidos } = montar({
      agendamentos: [
        { id: '9', idHardware: 'A', aplicarEmMs: AGORA - 1000, temperaturaDelta: 10 },
      ],
      config: undefined,
    });

    await agendador.verificar();

    assert.equal(aplicados.length, 0);
    assert.deepEqual(removidos, []);
  });

  it('uma falha ao listar nao derruba o servidor', async () => {
    const agendador = iniciarAgendador({
      listarAgendamentos: () => {
        throw new Error('banco fora');
      },
      aplicarComando: () => {},
      setIntervalFn: () => null,
      agora: () => AGORA,
      logger: { error() {} },
    });
    await assert.doesNotReject(() => agendador.verificar());
  });

  it('sem as funcoes obrigatorias nao inicia', () => {
    assert.equal(iniciarAgendador({}), null);
  });
});
