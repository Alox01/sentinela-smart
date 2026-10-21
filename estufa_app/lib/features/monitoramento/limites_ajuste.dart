/// Até onde o ajuste de temperatura pode ir, pedido pelo aplicativo.
///
/// ## Por que 165 °F
///
/// Decisão do produtor, em 16/10/2026, e o número é dele: é o topo do que a
/// cura dele exige. Acima disso não há estufada — há risco.
///
/// ## Onde mais isto existe
///
/// No firmware, como `ALVO_MAXIMO_F`, aplicado em `definirTemperaturaAlvo()`.
/// Lá o teto é de verdade: ele corta tanto o que vem dos botões quanto o que
/// chega pela nuvem, e é o aparelho quem tem a última palavra.
///
/// Aqui o teto é só de interface — serve para a tela não oferecer o que o
/// aparelho vai recusar. Sem ele, o produtor pedia 180, a tela mostrava 180
/// com "aguardando a estufa aplicar", o aparelho cortava para 165 e a tela
/// voltava sozinha: funciona, e parece defeito.
///
/// **O servidor continua aceitando até 200 °F** (`LIMITE_TEMPERATURA_MAX`, em
/// `sync.js` e `agendamentos.js`), de propósito: aquilo é guarda contra lixo,
/// não regra de produto, e apertar o limite lá rejeitaria um agendamento antigo
/// em vez de simplesmente cortá-lo. O maior alvo já registrado no banco é 160.
const double ajusteTemperaturaMinimoF = 50;
const double ajusteTemperaturaMaximoF = 165;
