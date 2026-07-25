const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  CANAL_ALERTAS,
  CANAL_CRITICO,
  CANAL_SEM_COMUNICACAO,
  CANAL_TEMPERATURA,
  acordaDeMadrugada,
  canalDoEvento,
  criarEnviadorPush,
  lerCredencial,
} = require('../push');

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

// Os ids vivem em dois repositorios de codigo diferentes (aqui e no Dart, em
// PushNotificationService). Nada em tempo de execucao liga os dois, entao o
// valor literal fica fixado aqui: mudar de um lado quebra o teste e lembra de
// mudar do outro.
describe('ids dos canais', () => {
  it('batem com os canais criados pelo app', () => {
    assert.equal(CANAL_CRITICO, 'sentinela_critico_v2');
    assert.equal(CANAL_ALERTAS, 'sentinela_alertas');
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

// SDK falso com a mesma forma da API modular do firebase-admin. Estes testes
// existem porque a versao anterior usava a API antiga (admin.apps), quebrava no
// boot e derrubava o servidor - e os testes de entao so cobriam o caminho SEM
// credencial, entao nao pegaram nada.
function sdkFalso({ falharInit = false, respostaEnvio } = {}) {
  const chamadas = { init: 0, enviadas: [] };
  return {
    chamadas,
    getApps: () => [],
    cert: (c) => ({ cert: c }),
    initializeApp: () => {
      chamadas.init++;
      if (falharInit) throw new Error('credencial recusada');
    },
    getMessaging: () => ({
      async sendEachForMulticast(msg) {
        chamadas.enviadas.push(msg);
        return (
          respostaEnvio ?? {
            successCount: msg.tokens.length,
            responses: msg.tokens.map(() => ({})),
          }
        );
      },
    }),
  };
}

describe('criarEnviadorPush com credencial', () => {
  const env = { FIREBASE_SERVICE_ACCOUNT: JSON.stringify(CREDENCIAL_FALSA) };
  const silencioso = { log() {}, error() {} };

  it('inicializa e habilita o envio', () => {
    const sdk = sdkFalso();
    const enviador = criarEnviadorPush({ env, logger: silencioso, sdk });
    assert.equal(enviador.habilitado, true);
    assert.equal(sdk.chamadas.init, 1);
  });

  it('uma falha ao inicializar desabilita, nao derruba o servidor', () => {
    const sdk = sdkFalso({ falharInit: true });
    assert.doesNotThrow(() => {
      const enviador = criarEnviadorPush({ env, logger: silencioso, sdk });
      assert.equal(enviador.habilitado, false);
    });
  });

  it('envia com o canal certo e sem tokens repetidos', async () => {
    const sdk = sdkFalso();
    const enviador = criarEnviadorPush({ env, logger: silencioso, sdk });
    const r = await enviador.enviar({
      tokens: ['a', 'a', 'b', null],
      titulo: 'Fogo',
      corpo: 'Verifique',
      evento: 'incendio',
      critico: true,
    });
    const msg = sdk.chamadas.enviadas[0];
    assert.deepEqual(msg.tokens, ['a', 'b']);
    // Um id divergente do app nao da erro nenhum: a notificacao so perde o som
    // de alarme, calada. Por isso o canal fica travado por teste.
    assert.equal(msg.android.notification.channelId, 'sentinela_critico_v2');
    assert.equal(msg.android.priority, 'high');
    assert.equal(r.enviados, 2);
  });

  it('devolve os tokens que o FCM diz nao existirem mais', async () => {
    const sdk = sdkFalso({
      respostaEnvio: {
        successCount: 1,
        responses: [
          {},
          { error: { code: 'messaging/registration-token-not-registered' } },
        ],
      },
    });
    const enviador = criarEnviadorPush({ env, logger: silencioso, sdk });
    const r = await enviador.enviar({ tokens: ['bom', 'morto'], titulo: 't', corpo: 'c' });
    assert.deepEqual(r.invalidos, ['morto']);
  });

  // Avisos de ESTADO (sem comunicacao / voltou) valem enquanto o estado vale.
  // Sem validade, o FCM guarda a mensagem enquanto o celular esta sem internet
  // e entrega na reconexao - o produtor recebia o alarme junto com o desmentido.
  it('aplica a validade quando informada', async () => {
    const sdk = sdkFalso();
    const enviador = criarEnviadorPush({ env, logger: silencioso, sdk });
    await enviador.enviar({
      tokens: ['a'],
      titulo: 'Estufa sem comunicação',
      corpo: 'Verifique',
      evento: 'semComunicacao',
      critico: true,
      validadeMs: 30 * 60 * 1000,
    });
    assert.equal(sdk.chamadas.enviadas[0].android.ttl, 1800000);
  });

  it('sem validade o FCM guarda indefinidamente (caso do incendio)', async () => {
    const sdk = sdkFalso();
    const enviador = criarEnviadorPush({ env, logger: silencioso, sdk });
    await enviador.enviar({
      tokens: ['a'],
      titulo: 'Fogo',
      corpo: 'Verifique',
      evento: 'incendio',
      critico: true,
    });
    // Ausente de proposito: um alerta de fogo perdido nao pode expirar.
    assert.equal('ttl' in sdk.chamadas.enviadas[0].android, false);
  });

  it('sem tokens nao chama o FCM', async () => {
    const sdk = sdkFalso();
    const enviador = criarEnviadorPush({ env, logger: silencioso, sdk });
    const r = await enviador.enviar({ tokens: [], titulo: 't', corpo: 'c' });
    assert.equal(r.enviados, 0);
    assert.equal(sdk.chamadas.enviadas.length, 0);
  });
});

describe('canal do evento', () => {
  // Com o app fechado o canal e tudo: e ele que decide se o aviso sai em volume
  // de alarme e se fura o "Nao perturbe". Errar aqui deixa o alerta mudo de
  // madrugada sem nenhum erro aparecer.
  it('incendio vai no canal critico', () => {
    assert.equal(canalDoEvento('incendio', true), CANAL_CRITICO);
  });

  it('temperatura fora da faixa tem canal proprio, nao o do incendio', () => {
    assert.equal(canalDoEvento('alarmeProcesso', false), CANAL_TEMPERATURA);
    assert.notEqual(canalDoEvento('alarmeProcesso', false), CANAL_CRITICO);
  });

  // Aparelho mudo acorda: as 3h pode ser queda de energia com estufada em
  // andamento. Antes ia no canal do incendio, o que acordava mas aparecia como
  // "Incendio" nas configuracoes do Android.
  it('sem comunicacao tem canal proprio, nao o do incendio', () => {
    assert.equal(canalDoEvento('semComunicacao', true), CANAL_SEM_COMUNICACAO);
    assert.notEqual(canalDoEvento('semComunicacao', true), CANAL_CRITICO);
  });

  // Mesmo evento do aviso de silencio, mas e boa noticia: acordar alguem para
  // dizer que esta tudo bem seria o oposto do util.
  it('"voltou a se comunicar" nao acorda ninguem', () => {
    assert.equal(canalDoEvento('semComunicacao', false), CANAL_ALERTAS);
    assert.equal(acordaDeMadrugada('semComunicacao', false), false);
  });

  // "Tocar" desligado NAO e mudo: e o canal comum, onde quem manda no bipe e na
  // vibracao e a configuracao do proprio celular, como em qualquer app. O
  // interruptor escolhe entre alarme e aviso comum, nada alem disso.
  it('sem toque, tudo cai no canal comum', () => {
    assert.equal(canalDoEvento('incendio', true, false), CANAL_ALERTAS);
    assert.equal(canalDoEvento('alarmeProcesso', false, false), CANAL_ALERTAS);
    assert.equal(canalDoEvento('semComunicacao', true, false), CANAL_ALERTAS);
  });
});

describe('prioridade', () => {
  it('os dois avisos que tiram da cama vao com prioridade alta', () => {
    assert.equal(acordaDeMadrugada('incendio', true), true);
    assert.equal(acordaDeMadrugada('alarmeProcesso', false), true);
  });

  it('o aviso de silencio tambem vai com prioridade alta', () => {
    assert.equal(acordaDeMadrugada('semComunicacao', true), true);
  });

  it('evento desconhecido nao acorda', () => {
    assert.equal(acordaDeMadrugada('qualquerOutro', false), false);
  });
});
