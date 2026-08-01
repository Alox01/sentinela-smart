const { log } = require('../log');

const ID_SIMULADOR = 'ESP32_REALISTIC_V2';

// Campos de ajuste e o timestamp que decide o LWW de cada um.
const CAMPO_TIMESTAMP = {
  temperaturaMeta: 'tempTimestamp',
  umidadeMeta: 'umidTimestamp',
  modoSilencioso: 'modoSilenciosoTimestamp',
  buzzerAtivo: 'buzzerTimestamp',
};

// O estado que as rotas dividem entre si: o que cada aparelho reportou por
// ultimo e o que ainda esta esperando para ser entregue a ele. Fica num modulo
// proprio porque e a unica coisa que as rotas de leitura, de comando e de push
// realmente compartilham - separadas as rotas por assunto, este e o assunto que
// sobra no meio.
function criarEstadoEstufa({ db, simulador }) {
  // Estado ao vivo por aparelho (idHardware -> { status, config, recebidoMs }),
  // alimentado pelos POST /leitura dos aparelhos reais. O simulador continua
  // sendo o aparelho ESP32_REALISTIC_V2, servido do seu proprio modelo, sem se
  // misturar com os reais.
  const dispositivosAoVivo = new Map();
  const ultimasLeiturasPersistidas = new Map();

  // Caixa de comandos por aparelho (idHardware -> config pendente). O aparelho
  // real nao e alcancavel de fora: quem manda e ele, empurrando leituras. Entao
  // o comando do app fica aqui ate o proprio aparelho vir buscar em
  // GET /comandos. O LWW por campo continua sendo resolvido no aparelho.
  const comandosPendentes = new Map();

  // O plano gratuito recicla o processo com frequencia; sem espelhar a caixa no
  // banco, um ajuste feito de longe sumia em silencio se o servidor reiniciasse
  // antes de o aparelho buscar. O mapa segue sendo a verdade em memoria; o
  // banco e so o backup de restart (falha nele nao derruba o comando).
  if (db?.carregarComandosPendentes && db.estaHabilitado?.()) {
    db.carregarComandosPendentes()
      .then((pendentes) => {
        for (const { idHardware, comando } of pendentes) {
          if (!comandosPendentes.has(idHardware)) {
            comandosPendentes.set(idHardware, comando);
          }
        }
        if (pendentes.length > 0) {
          log.debug(`Comandos pendentes restaurados: ${pendentes.length}`);
        }
      })
      .catch((error) => {
        log.erro('Falha ao restaurar comandos pendentes:', error.message);
      });
  }

  function guardarComandoPendente(idHardware, comando) {
    const pendente = comandosPendentes.get(idHardware) || {};
    // Campos diferentes convivem; o mesmo campo e sobrescrito pelo mais novo,
    // que e o mesmo criterio que o aparelho aplicaria de qualquer forma.
    const fundido = { ...pendente, ...comando };
    comandosPendentes.set(idHardware, fundido);
    if (db?.salvarComandoPendente) {
      db.salvarComandoPendente(idHardware, fundido).catch((error) => {
        log.erro('Falha ao persistir comando pendente:', error.message);
      });
    }
  }

  function comandoPendente(idHardware) {
    return comandosPendentes.get(idHardware) || null;
  }

  // Um comando so deixa de estar pendente quando o proprio aparelho reporta
  // aquele campo com timestamp igual ou mais novo - ou seja, quando ele
  // confirma que aplicou. Ate la a entrega se repete, o que e inofensivo
  // (o LWW no aparelho torna reaplicar idempotente) e cobre o caso de o
  // aparelho reiniciar logo depois de buscar.
  function limparPendentesConfirmados(idHardware, configDoAparelho) {
    const pendente = comandosPendentes.get(idHardware);
    if (!pendente || !configDoAparelho) return;

    const restante = { ...pendente };
    for (const [campo, chaveTimestamp] of Object.entries(CAMPO_TIMESTAMP)) {
      if (!Object.hasOwn(restante, campo)) continue;
      const tsPendente = Number(restante[chaveTimestamp]);
      const tsAparelho = Number(configDoAparelho[chaveTimestamp]);
      if (Number.isFinite(tsAparelho) && tsAparelho >= tsPendente) {
        delete restante[campo];
        delete restante[chaveTimestamp];
      }
    }

    if (Object.keys(restante).length === 0) {
      comandosPendentes.delete(idHardware);
      if (db?.removerComandoPendente) {
        db.removerComandoPendente(idHardware).catch((error) => {
          log.erro('Falha ao limpar comando pendente:', error.message);
        });
      }
    } else {
      comandosPendentes.set(idHardware, restante);
      if (db?.salvarComandoPendente) {
        db.salvarComandoPendente(idHardware, restante).catch((error) => {
          log.erro('Falha ao persistir comando pendente:', error.message);
        });
      }
    }
  }

  // O que o app deve ver: a config do aparelho com o comando pendente por cima.
  // Sem isso a tela voltava ao valor antigo poucos segundos depois de o usuario
  // mexer, ate o aparelho buscar o comando e reportar de volta.
  function configComPendente(idHardware, config) {
    const pendente = comandosPendentes.get(idHardware);
    if (!pendente) return { config, aguardandoAparelho: false };
    return { config: { ...config, ...pendente }, aguardandoAparelho: true };
  }

  async function lerDispositivo(idHardware) {
    if (!idHardware || idHardware === ID_SIMULADOR) {
      return simulador.lerCompleto();
    }
    const emMemoria = dispositivosAoVivo.get(idHardware);
    if (emMemoria) {
      return { status: emMemoria.status, config: emMemoria.config };
    }
    // Sob demanda: ultima leitura/config do banco (aparelho que ainda nao
    // empurrou nesta sessao do servidor).
    if (db.carregarUltimaLeitura) {
      const status = await db.carregarUltimaLeitura(idHardware);
      if (status) {
        const config = db.carregarConfiguracao
          ? await db.carregarConfiguracao(idHardware)
          : null;
        const registro = { status, config: config || {}, recebidoMs: 0 };
        dispositivosAoVivo.set(idHardware, registro);
        return { status, config: registro.config };
      }
    }
    return null;
  }

  // O timestamp servido usa a hora de recebimento para o app medir a staleness
  // sem depender do relogio do ESP; o historico mantem o timestamp original do
  // aparelho.
  function registrarLeituraAoVivo(idHardware, status, config) {
    const agoraMs = Date.now();
    dispositivosAoVivo.set(idHardware, {
      status: { ...status, timestampLeitura: agoraMs },
      config: config || dispositivosAoVivo.get(idHardware)?.config || {},
      recebidoMs: agoraMs,
    });
  }

  // O alvo vigente, para o agendamento resolver o "+10 F" no instante de
  // aplicar e nao no de agendar.
  function configVigente(idHardware) {
    return dispositivosAoVivo.get(idHardware)?.config;
  }

  function ultimoContatoAoVivoMs(idHardware) {
    return dispositivosAoVivo.get(idHardware)?.recebidoMs ?? 0;
  }

  function ultimaPersistida(idHardware) {
    return ultimasLeiturasPersistidas.get(idHardware);
  }

  function marcarPersistida(idHardware, registro) {
    ultimasLeiturasPersistidas.set(idHardware, registro);
  }

  return {
    guardarComandoPendente,
    comandoPendente,
    limparPendentesConfirmados,
    configComPendente,
    lerDispositivo,
    registrarLeituraAoVivo,
    configVigente,
    ultimoContatoAoVivoMs,
    ultimaPersistida,
    marcarPersistida,
  };
}

module.exports = {
  criarEstadoEstufa,
  ID_SIMULADOR,
};
