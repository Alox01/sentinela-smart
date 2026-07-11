// --- LOGICA DE NEGOCIO E SEGURANCA ---

// --- CONFIGURACOES DE TOLERANCIA ---
const TOLERANCIA_TEMP = 5.0; // Margem de erro de 5 F (alinhada com LEDs/eventos)
const TOLERANCIA_UMID = 2.0; // Margem de erro de 2%
const TEMPO_SILENCIO = 10 * 60 * 1000;

// Tabela de referencia (o sistema sabe o nome das fases)
const cicloDeCura = [
    { max: 100, nome: "1. Amarelacao" },
    { max: 110, nome: "2. Murchamento" },
    { max: 120, nome: "3. Fixacao da Cor" },
    { max: 135, nome: "4. Secagem da Folha" },
    { max: 150, nome: "5. Secagem do Talo" },
    { max: 165, nome: "6. ALERTA: AJUSTE DE TEMPERATURA ACIMA DO RECOMENDADO" },
    { max: 999, nome: "CRITICO: AJUSTE DE TEMPERATURA MUITO ELEVADO" }
];

module.exports = {
    analisarEstado: (tempAtual, tempAjuste, umidAtual, umidAjuste, timestampSilencio, sensorChamaAtivado) => {
        let tocarSirene = false;
        let perigoChama = false;
        let riscoIncendio = false;

        const agora = Date.now();
        const estaSilenciado = (agora - timestampSilencio) < TEMPO_SILENCIO;

        let corStatus = "green";
        let aviso = "";
        let faseAtual = "Desconhecida";

        // Se a ajuste for acima de 170 F, o limite de risco sobe para ajuste + 5 F.
        // Para ajustes normais, o limite de seguranca continua 175 F.
        const limiteFogo = tempAjuste > 170.0 ? (tempAjuste + 5.0) : 175.0;

        if (sensorChamaAtivado === true) {
            tocarSirene = true;
            perigoChama = true;
            corStatus = "red";
            aviso = "SENSOR DE CHAMA ATIVADO! SAIA IMEDIATAMENTE!";
            faseAtual = "FOGO DETECTADO";
        }
        else if (tempAtual > limiteFogo) {
            tocarSirene = true;
            riscoIncendio = true;
            corStatus = "red";
            aviso = `RISCO DE INCENDIO! (>${limiteFogo}F)`;
            faseAtual = "PERIGO: SUPERAQUECIMENTO";
        }
        else {
            for (let estagio of cicloDeCura) {
                if (tempAjuste <= estagio.max) {
                    faseAtual = estagio.nome;
                    break;
                }
            }

            const erroTemp = tempAtual - tempAjuste;
            const erroUmid = umidAtual - umidAjuste;

            if (Math.abs(erroTemp) > TOLERANCIA_TEMP) {
                tocarSirene = true;

                if (erroTemp > 0) {
                    corStatus = "orange";
                    aviso = "Temperatura Alta";
                } else {
                    corStatus = "purple";
                    aviso = "Temperatura Baixa";
                }
            }

            if (Math.abs(erroUmid) > TOLERANCIA_UMID) {
                let msgUmid = "";
                if (erroUmid > 0) msgUmid = "Umidade Alta";
                else msgUmid = "Umidade Baixa";

                if (aviso !== "") aviso += ` | ${msgUmid}`;
                else aviso = msgUmid;
            }

            if (corStatus === "green" && aviso === "") {
                aviso = "Estavel";
            }
        }

        if (estaSilenciado && tocarSirene) {
            tocarSirene = false;
            if (corStatus === "red") {
                corStatus = "deepOrange";
                faseAtual += " (SILENCIADO)";
            }
        }

        return {
            fase: faseAtual,
            corStatus: corStatus,
            aviso: aviso,
            alarmeAtivo: tocarSirene,
            perigoChama: perigoChama,
            riscoIncendio: riscoIncendio,
            alertaIncendio: tocarSirene // Compatibilidade com versoes anteriores do app
        };
    }
};
