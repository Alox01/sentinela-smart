// --- MODULO DE HARDWARE REAL (FUTURO) ---
// Aqui vai entrar o codigo da biblioteca serialport ou johnny-five
// quando o Arduino/ESP32 estiver conectado no USB.

// Estado temporario (placeholder)
let dadosReais = {
  temperatura: 0.0,
  umidade: 0.0,
  tempAjuste: 0.0,
  umidAjuste: 0.0,
  fase: 'Aguardando conexao serial...',
  corStatus: 'grey',
  sireneLigada: false,
};

module.exports = {
  iniciarConexao: () => {
    console.log('Tentando conectar na porta COM3 (exemplo)...');
    // Aqui vai a logica de conexao serial.
  },

  lerStatus: () => {
    // Aqui retornaria o que leu do Arduino/ESP32.
    return dadosReais;
  },

  comandoManual: (acao) => {
    console.log(`Enviando comando '${acao}' para o aparelho via serial...`);
    // port.write(acao);
  },

  silenciar: () => {
    console.log('Enviando comando de silenciar para o aparelho...');
  },
};
