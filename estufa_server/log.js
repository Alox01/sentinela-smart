// Niveis de log, para nao ser preciso escolher entre cego e afogado.
//
// O simulador narra clima e ajuste a cada ciclo, o que e util enquanto se
// desenvolve e vira ruido em producao - e ruido demais faz o erro de verdade
// passar batido no meio. Com `LOG_LEVEL=erro` no Render, sobra o que importa;
// na maquina de quem desenvolve, o padrao conta tudo.
//
// De proposito NAO ha nivel de "aviso": a diferenca entre aviso e erro nunca se
// sustenta sozinha, e mais niveis so adiam a pergunta de qual usar.

const NIVEIS = { silencioso: 0, erro: 1, info: 2, debug: 3 };
const PADRAO = 'info';

function nivelConfigurado(valor) {
  const nome = String(valor ?? '').trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(NIVEIS, nome) ? nome : PADRAO;
}

function criarLog({ nivel, saida = console } = {}) {
  const limite = NIVEIS[nivelConfigurado(nivel)];

  return {
    nivel: nivelConfigurado(nivel),
    /// Falha que alguem precisa ver. Nunca silenciada, exceto em `silencioso`,
    /// que existe so para os testes nao poluirem a saida.
    erro: (...args) => {
      if (limite >= NIVEIS.erro) saida.error(...args);
    },
    /// Acontecimento que conta a historia do servidor: subiu, deploy, comando
    /// aplicado. Sobrevive em producao.
    info: (...args) => {
      if (limite >= NIVEIS.info) saida.log(...args);
    },
    /// Narracao de ciclo - clima do simulador, cada leitura. Some em producao,
    /// porque repetida a cada segundo ela esconde todo o resto.
    debug: (...args) => {
      if (limite >= NIVEIS.debug) saida.log(...args);
    },
  };
}

// Instancia compartilhada, montada do ambiente. Os modulos usam esta; `criarLog`
// fica exposto para os testes poderem checar o filtro sem tocar no ambiente.
const log = criarLog({ nivel: process.env.LOG_LEVEL });

module.exports = { log, criarLog, nivelConfigurado, NIVEIS, PADRAO };
