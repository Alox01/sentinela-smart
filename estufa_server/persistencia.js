// Orquestra o reenvio das leituras guardadas no buffer offline para a nuvem.
// Usado tanto pelo agendador periodico quanto pela rota de ingestao, sempre
// preservando a ordem cronologica das leituras.
async function reprocessarBuffer({ db, buffer }) {
  const pendentes = await buffer.listar();
  if (pendentes.length === 0) return 0;

  let enviadas = 0;
  try {
    for (const registro of pendentes) {
      // Lanca se a nuvem ainda estiver indisponivel; paramos e guardamos o resto.
      await db.persistirLeituraBufferizada(registro);
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
