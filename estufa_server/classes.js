// estufa_server/classes.js

// CLASSE 1: O que está acontecendo fisicamente agora (Telemetria)
class StatusEstufa {
    constructor(idHardware) {
        this.idHardware = idHardware; 
        this.timestampLeitura = Date.now(); 

        // Sensores
        this.temperaturaAtual = 20.0; // Começa ambiente
        this.umidadeAtual = 60.0;
        
        // Status Críticos
        this.temEnergia = true;
        this.temInternet = true;
        this.sinalWifi = 100;
        
        // Alarmes e Atuadores
        this.alertaIncendio = false;
        this.ventiladorLigado = false;
        this.aquecedorLigado = false; // Adicionei para simulação física
        this.umidificadorLigado = false;
        
        // Logica de Negócio (Fases)
        this.faseAtual = "Iniciando...";
        this.aviso = "";
        this.corStatus = "grey";
    }
}

// CLASSE 2: O que nós queremos que aconteça (Metas/Controle)
class ConfiguracaoAlvo {
    constructor(idHardware) {
        this.idHardware = idHardware;
        
        // Controle de Temperatura
        this.temperaturaMeta = 25.0;
        this.tempTimestamp = 0; // 0 significa "nunca modificado"
        
        // Controle de Umidade
        this.umidadeMeta = 60.0;
        this.umidTimestamp = 0;
        
        // Comandos Gerais
        this.modoSilencioso = false;
        this.modoSilenciosoTimestamp = 0;
    }

    // Método Utilitário para verificar quem ganha (App ou Hardware)
    atualizarSeMaisRecente(chave, novoValor, timestampOrigem) {
        // Ex: chave = 'temperaturaMeta', timestampChave = 'tempTimestamp'
        const mapTime = {
            'temperaturaMeta': 'tempTimestamp',
            'umidadeMeta': 'umidTimestamp',
            'modoSilencioso': 'modoSilenciosoTimestamp'
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