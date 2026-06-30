const logica = require('./logica');
const { StatusEstufa, ConfiguracaoAlvo } = require('./classes');
const { aplicarSincronizacao } = require('./sync');

const ID_HARDWARE = 'ESP32_REALISTIC_V2';

const statusFisico = new StatusEstufa(ID_HARDWARE);
statusFisico.temperaturaAtual = 80.0;
statusFisico.umidadeAtual = 99.0;

const configLocal = new ConfiguracaoAlvo(ID_HARDWARE);
configLocal.temperaturaMeta = 90.0;
configLocal.umidadeMeta = 99.0;
configLocal.tempTimestamp = Date.now();
configLocal.umidTimestamp = Date.now();

let ultimoEventoTempo = Date.now();
const INTERVALO_MIN_EVENTO = 2 * 60 * 1000;
const CHANCE_EVENTO = 0.0085;

setInterval(() => {
  statusFisico.timestampLeitura = Date.now();
  const agora = Date.now();

  if (
    agora - ultimoEventoTempo > INTERVALO_MIN_EVENTO
    && Math.random() < CHANCE_EVENTO
  ) {
    const cenario = Math.floor(Math.random() * 4);
    let deltaT = 0;
    let deltaU = 0;
    let nomeCenario = '';

    switch (cenario) {
      case 0:
        nomeCenario = 'Chuva repentina';
        deltaT = -(Math.random() * 8 + 3);
        deltaU = Math.random() * 15 + 5;
        break;
      case 1:
        nomeCenario = 'Sol forte';
        deltaT = Math.random() * 10 + 4;
        deltaU = -(Math.random() * 15 + 5);
        break;
      case 2:
        nomeCenario = 'Frente fria seca';
        deltaT = -(Math.random() * 8 + 4);
        deltaU = -(Math.random() * 10 + 5);
        break;
      case 3:
        nomeCenario = 'Calor abafado';
        deltaT = Math.random() * 6 + 2;
        deltaU = Math.random() * 10 + 2;
        break;
      default:
        break;
    }

    console.log(`\n>>> [EVENTO] ${nomeCenario}! <<<`);
    console.log(`    Temp mudou ${deltaT.toFixed(0)} F | Umid mudou ${deltaU.toFixed(0)}%`);

    statusFisico.temperaturaAtual += deltaT;
    statusFisico.umidadeAtual += deltaU;

    if (statusFisico.umidadeAtual > 100) statusFisico.umidadeAtual = 100;
    if (statusFisico.umidadeAtual < 0) statusFisico.umidadeAtual = 0;

    ultimoEventoTempo = agora;
  }

  if (statusFisico.temperaturaAtual < configLocal.temperaturaMeta) {
    statusFisico.temperaturaAtual += 0.4;
    statusFisico.aquecedorLigado = true;
    statusFisico.ventiladorLigado = false;
  } else if (statusFisico.temperaturaAtual > configLocal.temperaturaMeta) {
    statusFisico.temperaturaAtual -= 0.4;
    statusFisico.aquecedorLigado = false;
    statusFisico.ventiladorLigado = true;
  } else {
    statusFisico.aquecedorLigado = false;
    statusFisico.ventiladorLigado = false;
  }

  if (statusFisico.umidadeAtual < configLocal.umidadeMeta) {
    statusFisico.umidadeAtual += 0.5;
    statusFisico.umidificadorLigado = true;
  } else if (statusFisico.umidadeAtual > configLocal.umidadeMeta) {
    statusFisico.umidadeAtual -= 0.5;
    statusFisico.umidificadorLigado = false;
  }

  if (statusFisico.umidadeAtual > 100) statusFisico.umidadeAtual = 100;
  if (statusFisico.umidadeAtual < 0) statusFisico.umidadeAtual = 0;

  statusFisico.temperaturaAtual = Math.round(statusFisico.temperaturaAtual * 10) / 10;
  statusFisico.umidadeAtual = Math.round(statusFisico.umidadeAtual * 10) / 10;

  const analise = logica.analisarEstado(
    statusFisico.temperaturaAtual,
    configLocal.temperaturaMeta,
    statusFisico.umidadeAtual,
    configLocal.umidadeMeta,
    configLocal.modoSilencioso ? configLocal.modoSilenciosoTimestamp : 0,
    false,
  );

  statusFisico.faseAtual = analise.fase;
  statusFisico.corStatus = analise.corStatus;
  statusFisico.aviso = analise.aviso;
  statusFisico.alarmeAtivo = analise.alarmeAtivo;
  statusFisico.perigoChama = analise.perigoChama;
  statusFisico.riscoIncendio = analise.riscoIncendio;
  statusFisico.alertaIncendio = analise.alertaIncendio;
}, 1000);

module.exports = {
  lerCompleto: () => ({ status: statusFisico, config: configLocal }),

  aplicarConfiguracaoPersistida: (configPersistida) => {
    if (!configPersistida) return false;

    if (typeof configPersistida.temperaturaMeta === 'number') {
      configLocal.temperaturaMeta = configPersistida.temperaturaMeta;
    }
    if (Number.isInteger(configPersistida.tempTimestamp)) {
      configLocal.tempTimestamp = configPersistida.tempTimestamp;
    }
    if (typeof configPersistida.umidadeMeta === 'number') {
      configLocal.umidadeMeta = configPersistida.umidadeMeta;
    }
    if (Number.isInteger(configPersistida.umidTimestamp)) {
      configLocal.umidTimestamp = configPersistida.umidTimestamp;
    }
    if (typeof configPersistida.modoSilencioso === 'boolean') {
      configLocal.modoSilencioso = configPersistida.modoSilencioso;
    }
    if (Number.isInteger(configPersistida.modoSilenciosoTimestamp)) {
      configLocal.modoSilenciosoTimestamp =
        configPersistida.modoSilenciosoTimestamp;
    }

    console.log(
      `Config persistida carregada: ${configLocal.temperaturaMeta} F / ${configLocal.umidadeMeta}%`,
    );
    return true;
  },

  aplicarStatusPersistido: (statusPersistido) => {
    if (!statusPersistido) return false;

    if (typeof statusPersistido.temperaturaAtual === 'number') {
      statusFisico.temperaturaAtual = statusPersistido.temperaturaAtual;
    }
    if (typeof statusPersistido.umidadeAtual === 'number') {
      statusFisico.umidadeAtual = statusPersistido.umidadeAtual;
    }
    if (typeof statusPersistido.alarmeAtivo === 'boolean') {
      statusFisico.alarmeAtivo = statusPersistido.alarmeAtivo;
    }
    if (typeof statusPersistido.perigoChama === 'boolean') {
      statusFisico.perigoChama = statusPersistido.perigoChama;
    }
    if (typeof statusPersistido.riscoIncendio === 'boolean') {
      statusFisico.riscoIncendio = statusPersistido.riscoIncendio;
    }
    if (typeof statusPersistido.alertaIncendio === 'boolean') {
      statusFisico.alertaIncendio = statusPersistido.alertaIncendio;
    }
    if (typeof statusPersistido.aviso === 'string') {
      statusFisico.aviso = statusPersistido.aviso;
    }
    if (typeof statusPersistido.corStatus === 'string') {
      statusFisico.corStatus = statusPersistido.corStatus;
    }
    if (typeof statusPersistido.faseAtual === 'string') {
      statusFisico.faseAtual = statusPersistido.faseAtual;
    }
    if (typeof statusPersistido.temEnergia === 'boolean') {
      statusFisico.temEnergia = statusPersistido.temEnergia;
    }
    if (typeof statusPersistido.temInternet === 'boolean') {
      statusFisico.temInternet = statusPersistido.temInternet;
    }
    if (Number.isInteger(statusPersistido.sinalWifi)) {
      statusFisico.sinalWifi = statusPersistido.sinalWifi;
    }
    if (typeof statusPersistido.aquecedorLigado === 'boolean') {
      statusFisico.aquecedorLigado = statusPersistido.aquecedorLigado;
    }
    if (typeof statusPersistido.ventiladorLigado === 'boolean') {
      statusFisico.ventiladorLigado = statusPersistido.ventiladorLigado;
    }
    if (typeof statusPersistido.umidificadorLigado === 'boolean') {
      statusFisico.umidificadorLigado = statusPersistido.umidificadorLigado;
    }

    console.log(
      `Status persistido carregado: ${statusFisico.temperaturaAtual} F / ${statusFisico.umidadeAtual}%`,
    );
    return true;
  },

  sincronizarConfiguracao: (configDoApp) => {
    const resultado = aplicarSincronizacao(configLocal, configDoApp);

    if (resultado.alteracoesAplicadas.includes('temperaturaMeta')) {
      console.log(`Novo ajuste de temperatura aceito: ${configLocal.temperaturaMeta} F`);
    }
    if (resultado.alteracoesAplicadas.includes('umidadeMeta')) {
      console.log(`Novo ajuste de umidade aceito: ${configLocal.umidadeMeta}%`);
    }
    if (resultado.alteracoesAplicadas.includes('modoSilencioso')) {
      console.log(`Modo silencioso atualizado: ${configLocal.modoSilencioso}`);
    }

    return resultado;
  },

  simularBotaoFisico: (tipo, valor) => {
    const agora = Date.now();
    if (tipo === 'temp') {
      configLocal.temperaturaMeta = valor;
      configLocal.tempTimestamp = agora;
      console.log(`Botao fisico alterou ajuste de temperatura para ${valor} F`);
    }
  },
};
