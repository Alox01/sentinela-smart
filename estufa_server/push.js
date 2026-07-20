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
const CANAL_CRITICO = 'sentinela_critico_v2';
const CANAL_ALERTAS = 'sentinela_alertas';

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
    async enviar({ tokens, titulo, corpo, evento, critico = false }) {
      const destinos = [...new Set((tokens ?? []).filter(Boolean))];
      if (destinos.length === 0) return { enviados: 0, invalidos: [] };

      const resposta = await messaging.sendEachForMulticast({
        tokens: destinos,
        notification: { title: titulo, body: corpo },
        data: { evento: String(evento ?? '') },
        android: {
          priority: critico ? 'high' : 'normal',
          notification: {
            // Com o app fechado quem desenha a notificacao e o Android, usando
            // SO as configuracoes do canal - o codigo Dart nem roda. Entao e
            // este id que decide se o alerta acorda alguem de madrugada.
            // O `_v2` acompanha o app (PushNotificationService.canalCriticoId):
            // o canal antigo tocava o bipe curto padrao, e o Android nao deixa
            // reconfigurar um canal ja criado.
            channelId: critico ? CANAL_CRITICO : CANAL_ALERTAS,
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

module.exports = { CANAL_ALERTAS, CANAL_CRITICO, criarEnviadorPush, lerCredencial };
