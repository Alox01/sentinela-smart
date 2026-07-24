// --- LOGICA DE NEGOCIO E SEGURANCA ---

// --- CONFIGURACOES DE TOLERANCIA ---
const TOLERANCIA_TEMP = 5.0; // Margem de erro de 5 F (alinhada com LEDs/eventos)
const TOLERANCIA_UMID = 2.0; // Margem de erro de 2%
const TEMPO_SILENCIO = 10 * 60 * 1000;
// Acomodacao apos mudar o ajuste: a estufa leva tempo para alcancar o alvo
// novo, e alarmar nesse caminho seria acusar um problema que o proprio produtor
// causou. A folga cobre SO a distancia que a mudanca criou - aproximar o alvo
// da leitura nao perdoa nada. Mesma regra do app e do firmware. Incendio nunca
// e afetado.
// 5 min: medido na estufa real, que alcanca um alvo 10-15 F acima em menos que
// isso. Janela maior so atrasaria o alerta de um desvio verdadeiro.
const TEMPO_ACOMODACAO = 5 * 60 * 1000;
const FOLGA_ACOMODACAO_MAX = 8;

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
    analisarEstado: (tempAtual, tempAjuste, umidAtual, umidAjuste, timestampSilencio, sensorChamaAtivado, acomodacao) => {
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
            aviso = "Sensor de chama ativado! Saia imediatamente!";
            faseAtual = "FOGO DETECTADO";
        }
        else if (tempAtual > limiteFogo) {
            tocarSirene = true;
            riscoIncendio = true;
            corStatus = "red";
            aviso = `Risco de incêndio! (>${limiteFogo}F)`;
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

            // Tolerancia vigente: a normal mais a folga da acomodacao, quando a
            // janela aberta pela ultima mudanca de ajuste ainda vale.
            let toleranciaTemp = TOLERANCIA_TEMP;
            if (acomodacao && Number.isFinite(acomodacao.desdeMs)
                && (agora - acomodacao.desdeMs) < TEMPO_ACOMODACAO) {
                const folga = Math.min(
                    Math.max(Number(acomodacao.folga) || 0, 0),
                    FOLGA_ACOMODACAO_MAX,
                );
                toleranciaTemp += folga;
            }

            if (Math.abs(erroTemp) > toleranciaTemp) {
                tocarSirene = true;

                if (erroTemp > 0) {
                    corStatus = "orange";
                    aviso = "Temperatura alta";
                } else {
                    corStatus = "purple";
                    aviso = "Temperatura baixa";
                }
            }

            if (Math.abs(erroUmid) > TOLERANCIA_UMID) {
                let msgUmid = "";
                if (erroUmid > 0) msgUmid = "Umidade alta";
                else msgUmid = "Umidade baixa";

                if (aviso !== "") aviso += ` | ${msgUmid}`;
                else aviso = msgUmid;
            }

            if (corStatus === "green" && aviso === "") {
                aviso = "Estável";
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
