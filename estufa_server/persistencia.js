// Reenvia as leituras guardadas no buffer offline, em ordem cronologica.
// O destino e generico (`enviar`): pode ser o banco em nuvem (persistencia
// local do servidor) ou um POST /leitura (ESP32 virtual empurrando para a
// nuvem). Em ambos os casos a ideia e a mesma: acumular quando o destino cai
// e drenar quando volta.
async function reprocessarBuffer({ buffer, enviar }) {
  const pendentes = await buffer.listar();
  if (pendentes.length === 0) return 0;

  let enviadas = 0;
  try {
    for (const registro of pendentes) {
      // Lanca se o destino ainda estiver indisponivel; paramos e guardamos o resto.
      await enviar(registro);
      enviadas += 1;
    }
  } finally {
    if (enviadas > 0) {
      await buffer.remover(enviadas);
    }
  }

  return enviadas;
}

module.exports = {
  reprocessarBuffer,
};
