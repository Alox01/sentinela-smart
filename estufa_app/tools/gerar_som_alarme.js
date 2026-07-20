// Gera o som do alerta critico (incendio) usado pelo canal de notificacao.
//
// Por que gerar em vez de baixar: o arquivo precisa estar no repositorio para o
// build funcionar em qualquer maquina, e um som de banco de sons traz licenca
// junto. Aqui o som e sintetizado, entao a origem e o proprio codigo.
//
// Uso: node tools/gerar_som_alarme.js
// Saida: android/app/src/main/res/raw/alarme_estufa.wav
//
// Formato: WAV PCM 16 bits, mono, 22050 Hz - o que o Android toca sem depender
// de codec. Duracao de 30 s: e o tempo que a notificacao fica soando, e foi
// escolhido para durar o suficiente para acordar alguem, sem virar um som
// infinito (que exigiria servico em primeiro plano).

const fs = require('fs');
const path = require('path');

const TAXA = 22050;
const DURACAO_S = 30;
const AMPLITUDE = 0.8; // deixa margem para nao estourar (clipping)

// Sirene de dois tons alternados, como alarme de emergencia. Frequencias altas
// o bastante para cortar ruido de fundo e serem audiveis por quem esta dormindo.
const TOM_AGUDO = 880;
const TOM_GRAVE = 660;
const DURACAO_TOM_S = 0.4;
const RAMPA_S = 0.01; // sobe e desce o volume na borda, senao estala

function amostras() {
  const total = Math.floor(TAXA * DURACAO_S);
  const dados = Buffer.alloc(total * 2);

  for (let i = 0; i < total; i += 1) {
    const t = i / TAXA;
    const passo = Math.floor(t / DURACAO_TOM_S);
    const freq = passo % 2 === 0 ? TOM_AGUDO : TOM_GRAVE;

    // Posicao dentro do tom atual, para aplicar a rampa nas duas pontas.
    const dentro = t - passo * DURACAO_TOM_S;
    const restante = DURACAO_TOM_S - dentro;
    let envelope = 1;
    if (dentro < RAMPA_S) envelope = dentro / RAMPA_S;
    else if (restante < RAMPA_S) envelope = restante / RAMPA_S;

    const valor = Math.sin(2 * Math.PI * freq * t) * AMPLITUDE * envelope;
    dados.writeInt16LE(Math.round(valor * 32767), i * 2);
  }

  return dados;
}

function cabecalhoWav(tamanhoDados) {
  const cabecalho = Buffer.alloc(44);
  const bytesPorAmostra = 2;
  const canais = 1;

  cabecalho.write('RIFF', 0);
  cabecalho.writeUInt32LE(36 + tamanhoDados, 4);
  cabecalho.write('WAVE', 8);
  cabecalho.write('fmt ', 12);
  cabecalho.writeUInt32LE(16, 16); // tamanho do bloco fmt
  cabecalho.writeUInt16LE(1, 20); // PCM
  cabecalho.writeUInt16LE(canais, 22);
  cabecalho.writeUInt32LE(TAXA, 24);
  cabecalho.writeUInt32LE(TAXA * canais * bytesPorAmostra, 28); // bytes por segundo
  cabecalho.writeUInt16LE(canais * bytesPorAmostra, 32); // alinhamento do bloco
  cabecalho.writeUInt16LE(8 * bytesPorAmostra, 34);
  cabecalho.write('data', 36);
  cabecalho.writeUInt32LE(tamanhoDados, 40);
  return cabecalho;
}

const dados = amostras();
const destino = path.join(
  __dirname,
  '..',
  'android',
  'app',
  'src',
  'main',
  'res',
  'raw',
  'alarme_estufa.wav',
);

fs.mkdirSync(path.dirname(destino), { recursive: true });
fs.writeFileSync(destino, Buffer.concat([cabecalhoWav(dados.length), dados]));

const kb = Math.round((dados.length + 44) / 1024);
console.log(`Gerado ${destino} (${kb} KB, ${DURACAO_S}s)`);
