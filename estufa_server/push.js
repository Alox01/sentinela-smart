// Envio de notificacoes push (FCM). A credencial vem de variavel de ambiente -
// a chave privada do service account nunca entra no repositorio.
//
// Sem credencial configurada o modulo fica desabilitado e o resto do servidor
// segue normal: push e camada extra de aviso, nao caminho critico.

let admin = null;
try {
  admin = require('firebase-admin');
} catch (_erro) {
  admin = null; // dependencia ausente (ex.: ambiente de teste enxuto)
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

function criarEnviadorPush({ env = process.env, logger = console } = {}) {
  const credencial = lerCredencial(env);

  if (!admin || !credencial) {
    const motivo = !admin
      ? 'dependencia firebase-admin ausente'
      : 'FIREBASE_SERVICE_ACCOUNT nao configurado';
    logger.log?.(`Push desabilitado: ${motivo}.`);
    return {
      habilitado: false,
      async enviar() {
        return { enviados: 0, invalidos: [] };
      },
    };
  }

  if (admin.apps.length === 0) {
    admin.initializeApp({ credential: admin.credential.cert(credencial) });
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

      const resposta = await admin.messaging().sendEachForMulticast({
        tokens: destinos,
        notification: { title: titulo, body: corpo },
        data: { evento: String(evento ?? '') },
        android: {
          priority: critico ? 'high' : 'normal',
          notification: {
            channelId: critico ? 'sentinela_critico' : 'sentinela_alertas',
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

module.exports = { criarEnviadorPush, lerCredencial };
