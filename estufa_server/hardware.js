// --- MÓDULO DE HARDWARE REAL (FUTURO) ---
// Aqui vai entrar o código da biblioteca 'serialport' ou 'johnny-five'
// quando o Arduino/ESP32 estiver conectado no USB.

// Estado temporário (placeholder)
let dadosReais = {
    temperatura: 0.0,
    umidade: 0.0,
    tempMeta: 0.0,
    umidMeta: 0.0,
    fase: "Aguardando Conexão Serial...",
    corStatus: "grey",
    sireneLigada: false
};

module.exports = {
    iniciarConexao: () => {
        console.log("Tentando conectar na porta COM3 (Exemplo)...");
        // Aqui vai a lógica de conexão serial
    },

    lerStatus: () => {
        // Aqui retornaria o que leu do Arduino
        return dadosReais;
    },

    comandoManual: (acao) => {
        console.log(`Enviando comando '${acao}' para o Arduino via Serial...`);
        // port.write(acao);
    },

    silenciar: () => {
        console.log("Enviando comando de silenciar para o Arduino...");
    }
};