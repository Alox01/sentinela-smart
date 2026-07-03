const fsp = require('fs/promises');
const path = require('path');

const CAMINHO_PADRAO = path.join(__dirname, '.buffer_leituras.jsonl');
const MAX_ENTRADAS_PADRAO = 5000;

// Buffer local em arquivo JSONL para leituras que nao puderam ser gravadas na
// nuvem (Supabase/Postgres indisponivel). Cada linha e um snapshot completo.
// Quando a conexao volta, o agendador reenvia essas leituras em ordem
// cronologica. Isso espelha, para o lado das leituras, a fila offline que o
// app ja mantem para os comandos.
function criarBufferLeituras({ caminho = CAMINHO_PADRAO, maxEntradas = MAX_ENTRADAS_PADRAO } = {}) {
  // Serializa as operacoes de arquivo para evitar corrupcao quando o
  // agendador reenvia o buffer enquanto a rota de ingestao grava uma leitura.
  let fila = Promise.resolve();

  function enfileirar(operacao) {
    const proxima = fila.then(operacao, operacao);
    // Mantem a cadeia viva mesmo quando uma operacao falha.
    fila = proxima.then(() => {}, () => {});
    return proxima;
  }

  async function lerLinhas() {
    let conteudo;
    try {
      conteudo = await fsp.readFile(caminho, 'utf8');
    } catch (erro) {
      if (erro.code === 'ENOENT') return [];
      throw erro;
    }

    return conteudo
      .split(/\r?\n/)
      .map((linha) => linha.trim())
      .filter((linha) => linha.length > 0);
  }

  async function escreverLinhas(linhas) {
    if (linhas.length === 0) {
      await fsp.rm(caminho, { force: true });
      return;
    }
    await fsp.writeFile(caminho, `${linhas.join('\n')}\n`, 'utf8');
  }

  return {
    caminho,

    async adicionar(dados) {
      return enfileirar(async () => {
        const linhas = await lerLinhas();
        linhas.push(JSON.stringify(dados));
        // Descarta as mais antigas quando o buffer estoura o limite.
        const excesso = linhas.length - maxEntradas;
        const finais = excesso > 0 ? linhas.slice(excesso) : linhas;
        await escreverLinhas(finais);
        return finais.length;
      });
    },

    async listar() {
      return enfileirar(async () => {
        const linhas = await lerLinhas();
        const registros = [];
        for (const linha of linhas) {
          try {
            registros.push(JSON.parse(linha));
          } catch (_erro) {
            // Ignora linha corrompida em vez de travar o reenvio.
          }
        }
        return registros;
      });
    },

    async remover(quantidade) {
      return enfileirar(async () => {
        if (quantidade <= 0) return;
        const linhas = await lerLinhas();
        await escreverLinhas(linhas.slice(quantidade));
      });
    },

    async tamanho() {
      return enfileirar(async () => (await lerLinhas()).length);
    },

    async limpar() {
      return enfileirar(async () => {
        await fsp.rm(caminho, { force: true });
      });
    },
  };
}

module.exports = {
  CAMINHO_PADRAO,
  MAX_ENTRADAS_PADRAO,
  criarBufferLeituras,
};
