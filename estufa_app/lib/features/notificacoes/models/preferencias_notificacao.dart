import 'dart:convert';

/// Um evento que pode gerar aviso, com dois interruptores independentes:
/// mostrar a mensagem e fazer o celular tocar/vibrar. O escopo e global: as
/// mesmas preferencias valem para todas as estufas.
enum EventoNotificacao {
  alarmeProcesso,
  incendio,
  faltaEnergia,
  semComunicacao,
}

extension EventoNotificacaoInfo on EventoNotificacao {
  String get chave => switch (this) {
    EventoNotificacao.alarmeProcesso => 'alarmeProcesso',
    EventoNotificacao.incendio => 'incendio',
    EventoNotificacao.faltaEnergia => 'faltaEnergia',
    EventoNotificacao.semComunicacao => 'semComunicacao',
  };

  String get titulo => switch (this) {
    EventoNotificacao.alarmeProcesso => 'Alarme de temperatura',
    EventoNotificacao.incendio => 'Inc\u00eandio / chama',
    EventoNotificacao.faltaEnergia => 'Falta de energia',
    EventoNotificacao.semComunicacao => 'Sem comunica\u00e7\u00e3o',
  };

  String get descricao => switch (this) {
    EventoNotificacao.alarmeProcesso => 'Temperatura fora da faixa do ajuste.',
    EventoNotificacao.incendio =>
      'Sensor de chama ou temperatura de inc\u00eandio. Cr\u00edtico.',
    EventoNotificacao.faltaEnergia => 'O aparelho avisou que a energia caiu.',
    EventoNotificacao.semComunicacao =>
      'A estufa parou de reportar (pode ser luz ou internet).',
  };

  bool get critico => this == EventoNotificacao.incendio;
}

/// Os dois interruptores de um evento.
class OpcaoEvento {
  final bool notificar;
  final bool tocarVibrar;

  const OpcaoEvento({required this.notificar, required this.tocarVibrar});

  OpcaoEvento copyWith({bool? notificar, bool? tocarVibrar}) => OpcaoEvento(
    notificar: notificar ?? this.notificar,
    tocarVibrar: tocarVibrar ?? this.tocarVibrar,
  );

  Map<String, dynamic> toJson() => {
    'notificar': notificar,
    'tocarVibrar': tocarVibrar,
  };

  factory OpcaoEvento.fromJson(Map<String, dynamic> json) => OpcaoEvento(
    notificar: json['notificar'] as bool? ?? true,
    tocarVibrar: json['tocarVibrar'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is OpcaoEvento &&
      other.notificar == notificar &&
      other.tocarVibrar == tocarVibrar;

  @override
  int get hashCode => Object.hash(notificar, tocarVibrar);
}

/// Preferencias de notificacao, por evento. Imutavel: mudar gera uma copia.
class PreferenciasNotificacao {
  final Map<EventoNotificacao, OpcaoEvento> porEvento;

  const PreferenciasNotificacao(this.porEvento);

  /// Padrao ligado: e mais seguro o produtor receber de mais do que de menos,
  /// e ele desliga o que nao quiser.
  factory PreferenciasNotificacao.padrao() => PreferenciasNotificacao({
    for (final evento in EventoNotificacao.values)
      evento: const OpcaoEvento(notificar: true, tocarVibrar: true),
  });

  OpcaoEvento opcao(EventoNotificacao evento) =>
      porEvento[evento] ??
      const OpcaoEvento(notificar: true, tocarVibrar: true);

  PreferenciasNotificacao comEvento(
    EventoNotificacao evento,
    OpcaoEvento opcao,
  ) {
    return PreferenciasNotificacao({...porEvento, evento: opcao});
  }

  Map<String, dynamic> toJson() => {
    for (final entry in porEvento.entries)
      entry.key.chave: entry.value.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory PreferenciasNotificacao.fromJsonString(String? texto) {
    if (texto == null || texto.isEmpty) return PreferenciasNotificacao.padrao();
    try {
      final mapa = jsonDecode(texto);
      if (mapa is! Map) return PreferenciasNotificacao.padrao();
      return PreferenciasNotificacao({
        for (final evento in EventoNotificacao.values)
          evento: mapa[evento.chave] is Map
              ? OpcaoEvento.fromJson(
                  Map<String, dynamic>.from(mapa[evento.chave] as Map),
                )
              : const OpcaoEvento(notificar: true, tocarVibrar: true),
      });
    } catch (_) {
      return PreferenciasNotificacao.padrao();
    }
  }
}
