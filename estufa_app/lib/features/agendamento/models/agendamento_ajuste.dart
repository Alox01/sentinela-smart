import 'dart:convert';

/// Um ajuste marcado para depois: "as 14h deixe em 120 F" ou "suba 10 F".
///
/// O valor pode ser **absoluto** (`temperaturaMeta`) ou **relativo**
/// (`temperaturaDelta`). O relativo e resolvido pelo servidor no instante de
/// aplicar, contra o alvo vigente — entre agendar e vencer o produtor pode ter
/// mexido na estufa, e "subir 10" significa 10 acima do que estiver.
class AgendamentoAjuste {
  /// Id do servidor. Nulo enquanto o agendamento so existe no celular (criado
  /// sem alcancar a nuvem).
  final String? id;

  /// Identificador local do alarme no Android. Precisa ser estavel para dar
  /// para cancelar depois, e caber em 32 bits.
  final int idLocal;

  final int idEstufa;
  final String nomeEstufa;
  final String? idHardware;
  final DateTime quando;

  final double? temperaturaMeta;
  final double? temperaturaDelta;
  final double? umidadeMeta;
  final double? umidadeDelta;

  const AgendamentoAjuste({
    this.id,
    required this.idLocal,
    required this.idEstufa,
    required this.nomeEstufa,
    this.idHardware,
    required this.quando,
    this.temperaturaMeta,
    this.temperaturaDelta,
    this.umidadeMeta,
    this.umidadeDelta,
  });

  /// Se o alvo chegou a ser registrado na nuvem. Sem isso, o alvo nao muda
  /// sozinho com o app fechado — so o aviso no celular acontece.
  bool get registradoNaNuvem => id != null;

  AgendamentoAjuste comId(String? novoId) => AgendamentoAjuste(
    id: novoId,
    idLocal: idLocal,
    idEstufa: idEstufa,
    nomeEstufa: nomeEstufa,
    idHardware: idHardware,
    quando: quando,
    temperaturaMeta: temperaturaMeta,
    temperaturaDelta: temperaturaDelta,
    umidadeMeta: umidadeMeta,
    umidadeDelta: umidadeDelta,
  );

  /// Texto curto do que vai acontecer, usado no aviso e na lista.
  String get descricao {
    final partes = <String>[];
    if (temperaturaMeta != null) {
      partes.add('temperatura para ${_num(temperaturaMeta!)}°F');
    } else if (temperaturaDelta != null) {
      partes.add('temperatura ${_comSinal(temperaturaDelta!)}°F');
    }
    if (umidadeMeta != null) {
      partes.add('umidade para ${_num(umidadeMeta!)}%');
    } else if (umidadeDelta != null) {
      partes.add('umidade ${_comSinal(umidadeDelta!)}%');
    }
    return partes.join(' e ');
  }

  static String _num(double v) => v.toStringAsFixed(0);
  static String _comSinal(double v) =>
      v >= 0 ? '+${_num(v)}' : '-${_num(v.abs())}';

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'idLocal': idLocal,
    'idEstufa': idEstufa,
    'nomeEstufa': nomeEstufa,
    if (idHardware != null) 'idHardware': idHardware,
    'quandoMs': quando.millisecondsSinceEpoch,
    if (temperaturaMeta != null) 'temperaturaMeta': temperaturaMeta,
    if (temperaturaDelta != null) 'temperaturaDelta': temperaturaDelta,
    if (umidadeMeta != null) 'umidadeMeta': umidadeMeta,
    if (umidadeDelta != null) 'umidadeDelta': umidadeDelta,
  };

  factory AgendamentoAjuste.fromJson(Map<String, dynamic> json) =>
      AgendamentoAjuste(
        id: json['id'] as String?,
        idLocal: (json['idLocal'] as num).toInt(),
        idEstufa: (json['idEstufa'] as num).toInt(),
        nomeEstufa: json['nomeEstufa'] as String? ?? '',
        idHardware: json['idHardware'] as String?,
        quando: DateTime.fromMillisecondsSinceEpoch(
          (json['quandoMs'] as num).toInt(),
        ),
        temperaturaMeta: (json['temperaturaMeta'] as num?)?.toDouble(),
        temperaturaDelta: (json['temperaturaDelta'] as num?)?.toDouble(),
        umidadeMeta: (json['umidadeMeta'] as num?)?.toDouble(),
        umidadeDelta: (json['umidadeDelta'] as num?)?.toDouble(),
      );

  static String listaParaJson(List<AgendamentoAjuste> itens) =>
      jsonEncode(itens.map((item) => item.toJson()).toList());

  static List<AgendamentoAjuste> listaDeJson(String? texto) {
    if (texto == null || texto.isEmpty) return const [];
    try {
      final lista = jsonDecode(texto);
      if (lista is! List) return const [];
      return lista
          .whereType<Map>()
          .map(
            (item) =>
                AgendamentoAjuste.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
