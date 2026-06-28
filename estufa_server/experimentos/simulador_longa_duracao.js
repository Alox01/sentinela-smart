const logica = require('../logica');
const { StatusEstufa, ConfiguracaoAlvo } = require('../classes');
const { aplicarSincronizacao } = require('../sync');

const ID_HARDWARE = 'ESP32_LONG_RUN_MANUAL';

const statusFisico = new StatusEstufa(ID_HARDWARE);
statusFisico.temperaturaAtual = 88.0;
statusFisico.umidadeAtual = 96.0;

const configLocal = new ConfiguracaoAlvo(ID_HARDWARE);
configLocal.temperaturaMeta = 90.0;
configLocal.umidadeMeta = 100.0;
configLocal.tempTimestamp = Date.now();
configLocal.umidTimestamp = Date.now();

const TICK_RATE_MS = 1000;
const INTERVALO_MIN_EVENTO_MS = 15 * 60 * 1000;
const INTERVALO_MAX_EVENTO_MS = 45 * 60 * 1000;
const CHANCE_EVENTO_POR_TICK = 0.015;
const TEMPERATURA_MIN = 70;
const TEMPERATURA_MAX = 170;
const UMIDADE_MIN = 0;
const UMIDADE_MAX = 100;

let proximoEventoMs = Date.now() + gerarIntervaloEvento();
let eventoAmbienteAtual = null;

console.log('[SIMULADOR] Longa duracao manual iniciado.');
console.log('[SIMULADOR] Produtor/app controla as metas; o simulador apenas responde com inercia.');

setInterval(() => {
  const agora = Date.now();
  statusFisico.timestampLeitura = agora;

  atualizarEventoAmbiente(agora);
  aplicarRespostaFisica();
  aplicarRuidoSensor();
  limitarGrandezas();
  arredondarLeituras();
  atualizarAnalise();
}, TICK_RATE_MS);

function aplicarRespostaFisica() {
  const fase = identificarFaixaCura(configLocal.temperaturaMeta);
  const diferencaTemp = configLocal.temperaturaMeta - statusFisico.temperaturaAtual;
  const diferencaUmid = configLocal.umidadeMeta - statusFisico.umidadeAtual;

  const passoTemp = calcularPasso(diferencaTemp, fase.respostaTemperatura);
  const passoUmid = calcularPasso(diferencaUmid, fase.respostaUmidade);

  statusFisico.temperaturaAtual += passoTemp;
  statusFisico.umidadeAtual += passoUmid;

  if (eventoAmbienteAtual) {
    statusFisico.temperaturaAtual += eventoAmbienteAtual.deltaTemp;
    statusFisico.umidadeAtual += eventoAmbienteAtual.deltaUmid;
  }

  statusFisico.aquecedorLigado = diferencaTemp > 0.8;
  statusFisico.ventiladorLigado = diferencaTemp < -0.8 || diferencaUmid < -1.5;
  statusFisico.umidificadorLigado = diferencaUmid > 1.5;
}

function calcularPasso(diferenca, respostaMaxima) {
  if (Math.abs(diferenca) < 0.05) return 0;

  const intensidade = Math.min(Math.abs(diferenca) / 12, 1);
  const passo = respostaMaxima * (0.35 + intensidade * 0.65);
  return Math.sign(diferenca) * Math.min(Math.abs(diferenca), passo);
}

function identificarFaixaCura(temperaturaMeta) {
  if (temperaturaMeta <= 100) {
    return {
      nome: 'amarelacao',
      respostaTemperatura: 0.08,
      respostaUmidade: 0.04,
    };
  }

  if (temperaturaMeta <= 110) {
    return {
      nome: 'murchamento',
      respostaTemperatura: 0.10,
      respostaUmidade: 0.06,
    };
  }

  if (temperaturaMeta <= 120) {
    return {
      nome: 'fixacao_cor',
      respostaTemperatura: 0.12,
      respostaUmidade: 0.08,
    };
  }

  if (temperaturaMeta <= 135) {
    return {
      nome: 'secagem_folha',
      respostaTemperatura: 0.14,
      respostaUmidade: 0.10,
    };
  }

  return {
    nome: 'secagem_talo',
    respostaTemperatura: 0.12,
    respostaUmidade: 0.08,
  };
}

function atualizarEventoAmbiente(agora) {
  if (eventoAmbienteAtual && agora >= eventoAmbienteAtual.fimMs) {
    console.log(`[CLIMA] ${eventoAmbienteAtual.nome} terminou.`);
    eventoAmbienteAtual = null;
  }

  if (eventoAmbienteAtual || agora < proximoEventoMs) return;

  if (Math.random() < CHANCE_EVENTO_POR_TICK) {
    eventoAmbienteAtual = criarEventoAmbiente(agora);
    console.log(`[CLIMA] ${eventoAmbienteAtual.nome} iniciado.`);
  }

  proximoEventoMs = agora + gerarIntervaloEvento();
}

function criarEventoAmbiente(agora) {
  const eventos = [
    {
      nome: 'Chuva prolongada',
      duracaoMs: 20 * 60 * 1000,
      deltaTemp: -0.015,
      deltaUmid: 0.035,
    },
    {
      nome: 'Frente fria',
      duracaoMs: 25 * 60 * 1000,
      deltaTemp: -0.025,
      deltaUmid: -0.01,
    },
    {
      nome: 'Sol forte no galpao',
      duracaoMs: 18 * 60 * 1000,
      deltaTemp: 0.02,
      deltaUmid: -0.025,
    },
    {
      nome: 'Ar externo mais seco',
      duracaoMs: 15 * 60 * 1000,
      deltaTemp: 0.005,
      deltaUmid: -0.035,
    },
  ];

  const escolhido = eventos[Math.floor(Math.random() * eventos.length)];
  return {
    ...escolhido,
    fimMs: agora + escolhido.duracaoMs,
  };
}

function aplicarRuidoSensor() {
  statusFisico.temperaturaAtual += (Math.random() - 0.5) * 0.08;
  statusFisico.umidadeAtual += (Math.random() - 0.5) * 0.12;
}

function limitarGrandezas() {
  statusFisico.temperaturaAtual = limitar(
    statusFisico.temperaturaAtual,
    TEMPERATURA_MIN,
    TEMPERATURA_MAX,
  );
  statusFisico.umidadeAtual = limitar(
    statusFisico.umidadeAtual,
    UMIDADE_MIN,
    UMIDADE_MAX,
  );
}

function arredondarLeituras() {
  statusFisico.temperaturaAtual =
    Math.round(statusFisico.temperaturaAtual * 10) / 10;
  statusFisico.umidadeAtual = Math.round(statusFisico.umidadeAtual * 10) / 10;
}

function atualizarAnalise() {
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
  statusFisico.alertaIncendio = analise.alertaIncendio;
}

function gerarIntervaloEvento() {
  return Math.floor(
    Math.random() * (INTERVALO_MAX_EVENTO_MS - INTERVALO_MIN_EVENTO_MS + 1)
      + INTERVALO_MIN_EVENTO_MS,
  );
}

function limitar(valor, minimo, maximo) {
  return Math.max(minimo, Math.min(maximo, valor));
}

function carregarConfiguracaoPersistida(configPersistida) {
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
}

function carregarStatusPersistido(statusPersistido) {
  if (!statusPersistido) return false;

  if (typeof statusPersistido.temperaturaAtual === 'number') {
    statusFisico.temperaturaAtual = statusPersistido.temperaturaAtual;
  }
  if (typeof statusPersistido.umidadeAtual === 'number') {
    statusFisico.umidadeAtual = statusPersistido.umidadeAtual;
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
}

module.exports = {
  lerCompleto: () => ({ status: statusFisico, config: configLocal }),

  aplicarConfiguracaoPersistida: carregarConfiguracaoPersistida,

  aplicarStatusPersistido: carregarStatusPersistido,

  sincronizarConfiguracao: (configDoApp) => {
    const resultado = aplicarSincronizacao(configLocal, configDoApp);

    if (resultado.alteracoesAplicadas.includes('temperaturaMeta')) {
      console.log(`Nova Meta Temp Aceita: ${configLocal.temperaturaMeta} F`);
    }
    if (resultado.alteracoesAplicadas.includes('umidadeMeta')) {
      console.log(`Nova Meta Umid Aceita: ${configLocal.umidadeMeta}%`);
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
      console.log(`Botao fisico alterou meta de temperatura para ${valor} F`);
    }
    if (tipo === 'umid') {
      configLocal.umidadeMeta = valor;
      configLocal.umidTimestamp = agora;
      console.log(`Botao fisico alterou meta de umidade para ${valor}%`);
    }
  },
};
