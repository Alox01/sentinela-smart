const fs = require('fs');
const path = require('path');

function carregarEnvLocal(caminho = path.join(__dirname, '.env')) {
  if (!fs.existsSync(caminho)) return;

  const linhas = fs.readFileSync(caminho, 'utf8').split(/\r?\n/);
  for (const linha of linhas) {
    const texto = linha.trim();
    if (!texto || texto.startsWith('#')) continue;

    const separador = texto.indexOf('=');
    if (separador <= 0) continue;

    const chave = texto.slice(0, separador).trim();
    const valorBruto = texto.slice(separador + 1).trim();
    const valor = removerAspas(valorBruto);

    if (!process.env[chave]) {
      process.env[chave] = valor;
    }
  }
}

function removerAspas(valor) {
  if (
    (valor.startsWith('"') && valor.endsWith('"')) ||
    (valor.startsWith("'") && valor.endsWith("'"))
  ) {
    return valor.slice(1, -1);
  }
  return valor;
}

module.exports = { carregarEnvLocal };
