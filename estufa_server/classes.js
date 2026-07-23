// estufa_server/classes.js

// CLASSE 1: O que esta acontecendo fisicamente agora (Telemetria)
class StatusEstufa {
    constructor(idHardware) {
        this.idHardware = idHardware;
        this.timestampLeitura = Date.now();

        // Sensores
        this.temperaturaAtual = 20.0; // Comeca ambiente
        this.umidadeAtual = 60.0;

        // Status criticos
        this.temEnergia = true;
        this.temInternet = true;
        this.sinalWifi = 100;

        // Alarmes e atuadores
        this.alarmeAtivo = false;
        this.perigoChama = false;
        this.riscoIncendio = false;
        this.alertaIncendio = false;
        this.ventiladorLigado = false;
        this.aquecedorLigado = false; // Simulacao fisica
        this.umidificadorLigado = false;

        // Logica de negocio (fases)
        this.faseAtual = "Iniciando...";
        this.aviso = "";
        this.corStatus = "grey";
    }
}

// CLASSE 2: O que queremos que aconteca (Ajustes/Controle)
class ConfiguracaoAlvo {
    constructor(idHardware) {
        this.idHardware = idHardware;

        // Controle de temperatura
        this.temperaturaMeta = 25.0;
        this.tempTimestamp = 0; // 0 significa "nunca modificado"

        // Controle de umidade
        this.umidadeMeta = 60.0;
        this.umidTimestamp = 0;

        // Comandos gerais
        this.modoSilencioso = false;
        this.modoSilenciosoTimestamp = 0;

        // Buzzer do alarme de temperatura ligado (fogo nunca e afetado)
        this.buzzerAtivo = true;
        this.buzzerTimestamp = 0;
    }

    // Metodo utilitario para verificar quem ganha (App ou Hardware)
    atualizarSeMaisRecente(chave, novoValor, timestampOrigem) {
        // Campos mantidos com nomes legados porque fazem parte do contrato da API.
        const mapTime = {
            'temperaturaMeta': 'tempTimestamp',
            'umidadeMeta': 'umidTimestamp',
            'modoSilencioso': 'modoSilenciosoTimestamp',
            'buzzerAtivo': 'buzzerTimestamp'
        };

        const chaveTime = mapTime[chave];

        // Se a nova ordem for mais recente que a que eu tenho:
        if (timestampOrigem > this[chaveTime]) {
            this[chave] = novoValor;
            this[chaveTime] = timestampOrigem;
            return true; // Atualizou
        }
        return false; // Ignorou (era dado velho)
    }
}

module.exports = { StatusEstufa, ConfiguracaoAlvo };