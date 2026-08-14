const test = require('node:test');
const assert = require('node:assert');

const { criarAlertasPush } = require('../routes/alertas_push');

// O aviso sai na BORDA: quando a condicao comeca, e nao a cada leitura enquanto
// ela dura. Isso evita acordar alguem de 60 em 60 segundos, mas tem um buraco
// que apareceu em campo — ver o teste do silencio, no fim.

function montar() {
  const enviados = [];
  const push = {
    habilitado: true,
    async enviar(mensagem) {
      enviados.push(mensagem);
      return { enviados: mensagem.tokens.length, invalidos: [] };
    },
  };
  const db = {
    async listarDispositivosPush() {
      return [{ tokenPush: 'tok', nome: 'Estufa 1', preferencias: null }];
    },
    async listarAparelhosComPush() {
      return [];
    },
  };
  const estado = { ultimoContatoAoVivoMs: () => 0 };
  const alertas = criarAlertasPush({ db, push, estado });
  return { alertas, enviados };
}

const foraDaFaixa = { alertaTemperatura: true };
const naFaixa = { alertaTemperatura: false };

test('avisa quando a temperatura sai da faixa', async () => {
  const { alertas, enviados } = montar();

  await alertas.avaliarAlertas('ESP32_AAA', foraDaFaixa);

  assert.equal(enviados.length, 1);
  assert.equal(enviados[0].evento, 'alarmeProcesso');
});

test('nao repete enquanto a condicao dura', async () => {
  const { alertas, enviados } = montar();

  await alertas.avaliarAlertas('ESP32_BBB', foraDaFaixa);
  await alertas.avaliarAlertas('ESP32_BBB', foraDaFaixa);
  await alertas.avaliarAlertas('ESP32_BBB', foraDaFaixa);

  // Um aviso por episodio: repetir a cada leitura ensina a ignorar.
  assert.equal(enviados.length, 1);
});

test('volta a avisar depois de normalizar', async () => {
  const { alertas, enviados } = montar();

  await alertas.avaliarAlertas('ESP32_CCC', foraDaFaixa);
  await alertas.avaliarAlertas('ESP32_CCC', naFaixa);
  await alertas.avaliarAlertas('ESP32_CCC', foraDaFaixa);

  assert.equal(enviados.length, 2);
});

// O buraco que custou um aviso de verdade: a estufa ficou desligada a noite e
// voltou de manha AINDA fora da faixa. O servidor comparava com o que sabia
// antes de ela sumir, concluia "ja estava assim" e nao avisava ninguem.
//
// Silencio do aparelho nao deixa o servidor sabendo de nada — entao ele tem de
// esquecer, e o retorno conta como subida nova.
test('depois do silencio, voltar fora da faixa avisa de novo', async () => {
  const { alertas, enviados } = montar();

  await alertas.avaliarAlertas('ESP32_DDD', foraDaFaixa);
  assert.equal(enviados.length, 1);

  // O watchdog avisa que o aparelho ficou mudo.
  await alertas.notificarEvento({
    idHardware: 'ESP32_DDD',
    evento: 'semComunicacao',
    titulo: 'Estufa sem comunicação',
    corpo: 'Parei de receber dados.',
    critico: true,
  });

  // Religada, ainda fria.
  await alertas.avaliarAlertas('ESP32_DDD', foraDaFaixa);

  const alarmes = enviados.filter((m) => m.evento === 'alarmeProcesso');
  assert.equal(
    alarmes.length,
    2,
    'a estufa voltou fora da faixa e ninguem foi avisado',
  );
});

test('"voltou a se comunicar" nao apaga o estado', async () => {
  const { alertas, enviados } = montar();

  await alertas.avaliarAlertas('ESP32_EEE', foraDaFaixa);

  // Boa noticia (critico: false) nao e silencio: o servidor continua sabendo o
  // que sabia, e repetir o alarme aqui seria aviso duplicado.
  await alertas.notificarEvento({
    idHardware: 'ESP32_EEE',
    evento: 'semComunicacao',
    titulo: 'Estufa voltou a se comunicar',
    corpo: 'A comunicação foi restabelecida.',
    critico: false,
  });
  await alertas.avaliarAlertas('ESP32_EEE', foraDaFaixa);

  const alarmes = enviados.filter((m) => m.evento === 'alarmeProcesso');
  assert.equal(alarmes.length, 1);
});
