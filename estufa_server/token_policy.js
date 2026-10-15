// Politica do token da API.
//
// Evita que o servidor suba em producao sem protecao ou com um token trivial
// (o que deixaria a API aberta para qualquer um ler ou comandar a estufa).
// Usado no boot (server.js): se o token nao passar, o servidor se recusa a
// iniciar, a menos que PERMITIR_SEM_TOKEN=true seja definido para uso local.

// Credenciais de oito caracteres ainda cabem no espaco de uma senha humana e
// sao pequenas demais para proteger comandos que alteram equipamento fisico.
// Dezesseis e o piso de compatibilidade; a recomendacao operacional continua
// sendo gerar pelo menos 32 bytes aleatorios.
const TAMANHO_MINIMO = 16;

const TOKENS_FRACOS = new Set([
  '12345678',
  '123456789',
  '1234567890',
  'password',
  'senha123',
  'changeme',
  'trocar123',
  'sentinela',
  'estufa123',
  'admin123',
]);

function avaliarTokenApi(token) {
  const valor = (token ?? '').trim();

  if (!valor) {
    return { ok: false, motivo: 'token nao configurado' };
  }
  if (valor.length < TAMANHO_MINIMO) {
    return {
      ok: false,
      motivo: `token muito curto (minimo ${TAMANHO_MINIMO} caracteres)`,
    };
  }
  if (TOKENS_FRACOS.has(valor.toLowerCase())) {
    return { ok: false, motivo: 'token fraco/previsivel' };
  }

  return { ok: true, motivo: 'ok' };
}

module.exports = { avaliarTokenApi, TAMANHO_MINIMO, TOKENS_FRACOS };
