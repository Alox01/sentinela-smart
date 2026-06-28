// --- LÓGICA DE NEGÓCIO E SEGURANÇA ---

// --- CONFIGURAÇÕES DE TOLERÂNCIA ---
const TOLERANCIA_TEMP = 2.0; // Margem de erro de 2°F
const TOLERANCIA_UMID = 2.0; // Margem de erro de 2%
const TEMPO_SILENCIO = 10 * 60 * 1000;

// Tabela de Referência (O Cérebro sabe o nome das fases)
const cicloDeCura = [
    { max: 100, nome: "1. Amarelação" },
    { max: 110, nome: "2. Murchamento" },
    { max: 120, nome: "3. Fixação da Cor" },
    { max: 135, nome: "4. Secagem da Folha" },
    { max: 150, nome: "5. Secagem do Talo" },
    { max: 165, nome: "6. ALERTA: AJUSTE DE TEMPERATURA ACIMA DO RECOMENDADO" },
    { max: 999, nome: "CRÍTICO: AJUSTE DE TEMPERATURA MUITO ELEVADO" }
];

module.exports = {
    analisarEstado: (tempAtual, tempMeta, umidAtual, umidMeta, timestampSilencio, sensorChamaAtivado) => {
        
        // Variável principal que decide se a sirene toca ou não
        let tocarSirene = false;

        // 1. VERIFICA SE O ALARME ESTÁ SILENCIADO
        const agora = Date.now();
        const estaSilenciado = (agora - timestampSilencio) < TEMPO_SILENCIO;

        let corStatus = "green"; 
        let aviso = "";
        let faseAtual = "Desconhecida";

        // --- LIMITE DINÂMICO DE FOGO ---
        // Se o operador for doido e botar a meta acima de 170, o limite de incêndio sobe para a Meta + 5°F.
        // Se a meta for normal, o limite de segurança continua sendo os 175°F padrão.
        const limiteFogo = tempMeta > 170.0 ? (tempMeta + 5.0) : 175.0;

        // --- CHECAGEM DE PERIGO IMEDIATO (FOGO) ---
        if (sensorChamaAtivado === true) {
            tocarSirene = true; 
            corStatus = "red";
            aviso = "SENSOR DE CHAMA ATIVADO! SAIA IMEDIATAMENTE!";
            faseAtual = "🔥 FOGO DETECTADO 🔥";
        }
        else if (tempAtual > limiteFogo) {
            tocarSirene = true; // Superaquecimento acima do risco assumido liga a sirene
            corStatus = "red";
            aviso = `RISCO DE INCÊNDIO! (>${limiteFogo}°F)`;
            faseAtual = "🔥 PERIGO: SUPERAQUECIMENTO";
        }
        else {
            // --- CHECAGEM DE PROCESSO NORMAL ---
            
            // Identificar Fase
            for (let estagio of cicloDeCura) {
                if (tempMeta <= estagio.max) {
                    faseAtual = estagio.nome;
                    break;
                }
            }

        // Cálculos de erro (O quão longe a realidade está do desejo?)
        const erroTemp = tempAtual - tempMeta; 
        const erroUmid = umidAtual - umidMeta;

        // Lógica da Temperatura (AQUI MUDOU)
            if (Math.abs(erroTemp) > TOLERANCIA_TEMP) {
                // Se a diferença for maior que 2 graus (para cima ou para baixo):
                tocarSirene = true; // <--- AGORA LIGA A SIRENE AQUI TAMBÉM

                if (erroTemp > 0) {
                    corStatus = "orange"; 
                    aviso = `Temp Alta (+${erroTemp.toFixed(0)}°F)`;
                } else {
                    corStatus = "purple"; 
                    aviso = `Temp Baixa (${erroTemp.toFixed(0)}°F)`;
                }
            }

            // Lógica da Umidade (Geralmente umidade não toca sirene, só avisa, mas se quiser pode por tocarSirene = true aqui também)
            if (Math.abs(erroUmid) > TOLERANCIA_UMID) {
                let msgUmid = "";
                if (erroUmid > 0) msgUmid = `Umidade Alta (+${erroUmid.toFixed(0)}%)`;
                else msgUmid = `Umidade Baixa (${erroUmid.toFixed(0)}%)`;

                if (aviso !== "") aviso += ` | ${msgUmid}`;
                else aviso = msgUmid;
            }

            if (corStatus === "green" && aviso === "") {
                aviso = "Estável";
            }
        }

        // --- FILTRO FINAL DE SILÊNCIO ---
        // Se o operador apertou o botão de silenciar, desligamos o som (mas mantemos a cor e o aviso)
        if (estaSilenciado && tocarSirene) {
            tocarSirene = false;
            // Se era fogo (vermelho), mudamos para laranja escuro para indicar "Perigo Silenciado"
            if (corStatus === "red") {
                corStatus = "deepOrange";
                faseAtual += " (SILENCIADO)";
            }
        }

        return {
            fase: faseAtual,
            corStatus: corStatus,
            aviso: aviso,
            alertaIncendio: tocarSirene // O App lê essa variável para tocar o sino
        };
    }
};
