/// Evento de oscilacao detectado (a leitura ficou fora do ajuste por tempo
/// suficiente). O widget e quem registra o evento/leitura de fato.
class EventoOscilacao {
  final String tipo;
  final String severidade;
  final String descricao;
  final double? valorAnterior;
  final double valorAtual;

  const EventoOscilacao({
    required this.tipo,
    required this.severidade,
    required this.descricao,
    this.valorAnterior,
    required this.valorAtual,
  });
}

class _EstadoGrandeza {
  String estado = 'normal';
  String? pendente;
  int? desdeMs;
  int ultimoRegistroMs = 0;
  int acomodacaoAteMs = 0;

  // Reinicia so a maquina de oscilacao (a janela de acomodacao e preservada,
  // como no comportamento original ao iniciar/finalizar ciclo).
  void reiniciar() {
    estado = 'normal';
    pendente = null;
    desdeMs = null;
    ultimoRegistroMs = 0;
  }
}

/// Maquina de estados que decide quando a temperatura/umidade esta "oscilando"
/// (fora do ajuste) de forma relevante, com persistencia no tempo e uma janela
/// de acomodacao apos mudar o ajuste (para nao confundir a estufa perseguindo o
/// novo alvo com uma oscilacao de clima). Logica pura, sem dependencia de UI.
class DetectorOscilacao {
  static const int _tempoOscilacaoAtencaoMs = 10 * 60 * 1000;
  static const int _tempoOscilacaoCriticaMs = 5 * 60 * 1000;
  static const int _intervaloContinuaMs = 10 * 60 * 1000;
  static const int _tempoAcomodacaoAjusteMs = 20 * 60 * 1000;
  static const double _tolerancia = 5;

  final _EstadoGrandeza _temperatura = _EstadoGrandeza();
  final _EstadoGrandeza _umidade = _EstadoGrandeza();

  void reiniciar() {
    _temperatura.reiniciar();
    _umidade.reiniciar();
  }

  void registrarMudancaAjusteTemperatura(int nowMs) {
    _temperatura.acomodacaoAteMs = nowMs + _tempoAcomodacaoAjusteMs;
  }

  void registrarMudancaAjusteUmidade(int nowMs) {
    _umidade.acomodacaoAteMs = nowMs + _tempoAcomodacaoAjusteMs;
  }

  bool temperaturaEmAcomodacao(int nowMs) =>
      nowMs < _temperatura.acomodacaoAteMs;

  bool umidadeEmAcomodacao(int nowMs) => nowMs < _umidade.acomodacaoAteMs;

  EventoOscilacao? avaliarTemperatura({
    required double leitura,
    required double ajuste,
    required int nowMs,
  }) {
    return _avaliar(
      estado: _temperatura,
      leitura: leitura,
      ajuste: ajuste,
      nowMs: nowMs,
      prefixoTipo: 'temperatura',
      nomeGrandeza: 'Temperatura',
      unidade: '°F',
      limiteAtencaoTexto: '10°F',
      limiteCriticoTexto: '20°F',
    );
  }

  EventoOscilacao? avaliarUmidade({
    required double leitura,
    required double ajuste,
    required int nowMs,
  }) {
    return _avaliar(
      estado: _umidade,
      leitura: leitura,
      ajuste: ajuste,
      nowMs: nowMs,
      prefixoTipo: 'umidade',
      nomeGrandeza: 'Umidade',
      unidade: '%',
      limiteAtencaoTexto: '5%',
      limiteCriticoTexto: '20%',
    );
  }

  EventoOscilacao? _avaliar({
    required _EstadoGrandeza estado,
    required double leitura,
    required double ajuste,
    required int nowMs,
    required String prefixoTipo,
    required String nomeGrandeza,
    required String unidade,
    required String limiteAtencaoTexto,
    required String limiteCriticoTexto,
  }) {
    final diferenca = leitura - ajuste;
    final diferencaAbs = diferenca.abs();
    final estadoAlvo = diferencaAbs > 20
        ? 'critico'
        : diferencaAbs > _tolerancia
        ? 'atencao'
        : 'normal';

    if (estadoAlvo == 'normal') {
      estado.pendente = null;
      estado.desdeMs = null;
      estado.ultimoRegistroMs = 0;
      if (estado.estado != 'normal') {
        estado.estado = 'normal';
        return EventoOscilacao(
          tipo: 'oscilacao_${prefixoTipo}_normalizada',
          severidade: 'info',
          descricao: '$nomeGrandeza voltou para a faixa proxima do ajuste.',
          valorAtual: leitura,
        );
      }
      return null;
    }

    // Durante a acomodacao apos mudar o ajuste, a diferenca de "atencao" e
    // esperada (estufa indo ate o novo alvo): zera o relogio e nao gera evento.
    // O nivel critico (>20) segue valendo como alarme.
    if (estadoAlvo == 'atencao' && nowMs < estado.acomodacaoAteMs) {
      estado.pendente = 'atencao';
      estado.desdeMs = nowMs;
      return null;
    }
    if (estado.pendente != estadoAlvo) {
      estado.pendente = estadoAlvo;
      estado.desdeMs = nowMs;
      return null;
    }

    final tempoMinimo = estadoAlvo == 'critico'
        ? _tempoOscilacaoCriticaMs
        : _tempoOscilacaoAtencaoMs;
    final desdeMs = estado.desdeMs ?? nowMs;
    if ((nowMs - desdeMs) < tempoMinimo) return null;

    if (estado.estado == estadoAlvo) {
      if ((nowMs - estado.ultimoRegistroMs) < _intervaloContinuaMs) {
        return null;
      }
      estado.ultimoRegistroMs = nowMs;
      return EventoOscilacao(
        tipo: 'oscilacao_${prefixoTipo}_continua',
        severidade: estadoAlvo == 'critico' ? 'critico' : 'alerta',
        descricao:
            '$nomeGrandeza ainda fora do ajuste (${diferencaAbs.toStringAsFixed(0)}$unidade de diferença).',
        valorAnterior: ajuste,
        valorAtual: leitura,
      );
    }

    estado.estado = estadoAlvo;
    estado.ultimoRegistroMs = nowMs;
    final direcao = diferenca > 0 ? 'acima' : 'abaixo';
    final limiteTexto = estadoAlvo == 'critico'
        ? limiteCriticoTexto
        : limiteAtencaoTexto;
    return EventoOscilacao(
      tipo: 'oscilacao_$prefixoTipo',
      severidade: estadoAlvo == 'critico' ? 'critico' : 'alerta',
      descricao:
          '$nomeGrandeza $direcao do ajuste por mais de $limiteTexto (${diferencaAbs.toStringAsFixed(0)}$unidade de diferença).',
      valorAnterior: ajuste,
      valorAtual: leitura,
    );
  }
}
