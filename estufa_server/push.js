// Envio de notificacoes push (FCM). A credencial vem de variavel de ambiente -
// a chave privada do service account nunca entra no repositorio.
//
// Regra de ouro deste modulo: **nada aqui pode derrubar o servidor**. Push e
// camada extra de aviso; se a credencial faltar, for invalida ou o SDK mudar de
// forma, o modulo se desabilita e o resto (leituras, comandos, historico) segue
// funcionando. Ja aconteceu de um erro na inicializacao matar o processo no
// boot - por isso a inicializacao inteira vive dentro de um try/catch.

// Precisam ser identicos aos canais criados pelo app. Se divergirem, o Android
// entrega a notificacao no canal padrao (ou descarta, dependendo da versao) e o
// alerta perde o som de alarme sem erro nenhum aparecer.
// v3: o incendio ganhou sirene propria no app (`sirene_incendio.mp3`). Canal ja
// criado nao se reconfigura, entao trocar o som exige trocar o ID — e o ID tem
// de subir aqui junto, senao o push chega com canal que nao existe no aparelho.
const CANAL_CRITICO = 'sentinela_critico_v3';
const CANAL_ALERTAS = 'sentinela_alertas';
// Temperatura fora da faixa toca em volume de ALARME, como o incendio, porque e
// de madrugada que ela precisa acordar alguem - o volume de notificacao costuma
// ficar baixo justamente quando mais importa. Canal separado do incendio de
// proposito: se dividissem o canal, um desvio de temperatura tocaria a sirene de
// fogo, e o produtor perderia a diferenca entre "va ver" e "corra".
const CANAL_TEMPERATURA = 'sentinela_temperatura_v1';

// Aparelho mudo tambem tira da cama: as 3h da manha pode ser queda de energia
// com a estufada em andamento. Ate agora este aviso ia no canal do INCENDIO
// (porque o watchdog o marca como critico), o que funcionava para acordar mas
// aparecia como "Incendio" nas configuracoes do Android - o produtor nao
// conseguia silenciar um sem perder o outro.
const CANAL_SEM_COMUNICACAO = 'sentinela_sem_comunicacao_v1';

// Temperatura acima do limite de incendio (175 F). Evento separado do sensor de
// chama porque as causas sao independentes: o produtor pode querer desligar o
// aviso de uma sem perder o da outra.
const CANAL_TEMP_MUITO_ALTA = 'sentinela_temp_muito_alta_v1';

// Um aviso por assunto: assim o produtor silencia o que quiser nas
// configuracoes do Android sem levar os outros junto.
const CANAIS_QUE_ACORDAM = {
  incendio: CANAL_CRITICO,
  temperaturaMuitoAlta: CANAL_TEMP_MUITO_ALTA,
  alarmeProcesso: CANAL_TEMPERATURA,
  semComunicacao: CANAL_SEM_COMUNICACAO,
};

/// Canal do Android que o aviso vai usar. Com o app fechado e ele, sozinho, que
/// decide som, volume e se fura o "Nao perturbe".
///
/// `comToque` e o interruptor "Tocar" do app, e ele decide **so** entre alarme e
/// notificacao comum. Desligado NAO significa mudo: a mensagem continua chegando
/// pelo canal normal, e ai quem manda no bipe e na vibracao e a configuracao do
/// proprio celular, como em qualquer app.
function canalDoEvento(evento, critico, comToque = true) {
  if (!comToque) return CANAL_ALERTAS;
  // "Voltou a se comunicar" usa o mesmo evento do aviso de silencio, mas e boa
  // noticia: acordar alguem para dizer que esta tudo bem seria o oposto do util.
  // O watchdog distingue os dois pelo `critico`.
  if (evento === 'semComunicacao' && !critico) return CANAL_ALERTAS;
  return CANAIS_QUE_ACORDAM[evento] ?? CANAL_ALERTAS;
}

/// Avisos que precisam chegar mesmo com o celular em repouso. Prioridade normal
/// e agrupada pelo Android e pode esperar - inaceitavel para os casos em que o
/// produtor teria de sair da cama.
function acordaDeMadrugada(evento, critico) {
  if (evento === 'semComunicacao') return critico === true;
  return Boolean(CANAIS_QUE_ACORDAM[evento]);
}

function carregarSdk() {
  try {
    // API modular (firebase-admin v10+). O namespace antigo (admin.apps) foi
    // removido nas versoes recentes.
    const app = require('firebase-admin/app');
    const messaging = require('firebase-admin/messaging');
    return {
      getApps: app.getApps,
      initializeApp: app.initializeApp,
      cert: app.cert,
      getMessaging: messaging.getMessaging,
    };
  } catch (_erro) {
    return null;
  }
}

function lerCredencial(env = process.env) {
  const bruto = (env.FIREBASE_SERVICE_ACCOUNT ?? '').trim();
  if (!bruto) return null;
  try {
    // Aceita o JSON cru ou em base64 (facilita colar no painel do Render).
    const texto = bruto.startsWith('{')
      ? bruto
      : Buffer.from(bruto, 'base64').toString('utf8');
    const credencial = JSON.parse(texto);
    if (!credencial.project_id || !credencial.private_key) return null;
    return credencial;
  } catch (_erro) {
    return null;
  }
}

function criarEnviadorPush({
  env = process.env,
  logger = console,
  sdk = undefined,
} = {}) {
  const desabilitado = (motivo) => {
    logger.log?.(`Push desabilitado: ${motivo}.`);
    return {
      habilitado: false,
      async enviar() {
        return { enviados: 0, invalidos: [] };
      },
    };
  };

  const firebase = sdk === undefined ? carregarSdk() : sdk;
  if (!firebase) return desabilitado('dependencia firebase-admin indisponivel');

  const credencial = lerCredencial(env);
  if (!credencial) return desabilitado('FIREBASE_SERVICE_ACCOUNT nao configurado');

  let messaging;
  try {
    if (firebase.getApps().length === 0) {
      firebase.initializeApp({ credential: firebase.cert(credencial) });
    }
    messaging = firebase.getMessaging();
  } catch (erro) {
    // Credencial malformada, relogio fora, SDK incompativel... nada disso
    // justifica o servidor nao subir.
    return desabilitado(`falha ao inicializar o Firebase (${erro.message})`);
  }

  logger.log?.(`Push habilitado (projeto ${credencial.project_id}).`);

  return {
    habilitado: true,
    /**
     * Envia a mesma mensagem para varios tokens. Devolve os tokens que o FCM
     * recusou por nao existirem mais, para o chamador limpar o cadastro - sem
     * isso a lista so cresce com aparelhos que desinstalaram o app.
     */
    async enviar({
      tokens,
      titulo,
      corpo,
      evento,
      critico = false,
      validadeMs,
      comToque = true,
    }) {
      const destinos = [...new Set((tokens ?? []).filter(Boolean))];
      if (destinos.length === 0) return { enviados: 0, invalidos: [] };

      const resposta = await messaging.sendEachForMulticast({
        tokens: destinos,
        notification: { title: titulo, body: corpo },
        // `acorda` existe porque, com o app ABERTO, quem monta o aviso e o
        // codigo Dart, e ele nao consegue distinguir "sem comunicacao" de
        // "voltou a se comunicar" (mesmo evento) para saber se deve tocar.
        data: {
          evento: String(evento ?? ''),
          acorda: comToque && acordaDeMadrugada(evento, critico) ? 'true' : 'false',
        },
        android: {
          priority: comToque && acordaDeMadrugada(evento, critico) ? 'high' : 'normal',
          // Quando o celular esta sem internet o FCM guarda a mensagem e
          // entrega na reconexao. Para avisos de estado isso vira susto
          // atrasado: o produtor recebe "sem comunicacao" junto com o "voltou
          // a se comunicar". Com validade, o FCM descarta o que envelheceu em
          // vez de entregar um alarme que ja nao vale. Alertas sem validade
          // (fogo) seguem sendo guardados indefinidamente.
          ...(Number.isFinite(validadeMs)
            ? { ttl: Math.max(0, Math.floor(validadeMs)) }
            : {}),
          notification: {
            // Com o app fechado quem desenha a notificacao e o Android, usando
            // SO as configuracoes do canal - o codigo Dart nem roda. Entao e
            // este id que decide se o alerta acorda alguem de madrugada.
            // O `_v2` acompanha o app (PushNotificationService.canalCriticoId):
            // o canal antigo tocava o bipe curto padrao, e o Android nao deixa
            // reconfigurar um canal ja criado.
            channelId: canalDoEvento(evento, critico, comToque),
          },
        },
      });

      const invalidos = [];
      resposta.responses.forEach((r, i) => {
        const codigo = r.error?.code ?? '';
        if (
          codigo.includes('registration-token-not-registered') ||
          codigo.includes('invalid-argument')
        ) {
          invalidos.push(destinos[i]);
        }
      });

      return { enviados: resposta.successCount, invalidos };
    },
  };
}

module.exports = {
  CANAL_ALERTAS,
  CANAL_CRITICO,
  CANAL_SEM_COMUNICACAO,
  CANAL_TEMPERATURA,
  CANAL_TEMP_MUITO_ALTA,
  acordaDeMadrugada,
  canalDoEvento,
  criarEnviadorPush,
  lerCredencial,
};
