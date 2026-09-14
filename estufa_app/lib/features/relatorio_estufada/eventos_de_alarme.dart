import '../../models/evento_ciclo_entity.dart';
import '../../models/historico_leitura_entity.dart';

/// Os alarmes que as LEITURAS mostram e que o app nao gravou como evento.
///
/// O evento de alarme nasce no app, e so com a tela da estufa aberta. Com o app
/// fechado o alarme tocava, a notificacao chegava — e o relatorio continuava
/// dizendo "3 alarmes" (teste de 14/09/2026). Cada leitura guarda se havia
/// alarme naquela hora, e a nuvem grava uma leitura sempre que isso muda; entao
/// o comeco e o fim de cada alarme ja estao nas leituras.
///
/// So entra o que o app NAO registrou: um evento tirado das leituras e
/// descartado quando ja existe um do mesmo tipo a menos de [mesmoEpisodio] —
/// ali o app estava aberto e o evento dele e mais preciso (sabe, por exemplo, se
/// a sirene estava desligada).
///
/// Um alarme mais curto que a distancia entre duas leituras (a uniao com a
/// nuvem guarda uma por minuto) pode nao aparecer. Para temperatura fora da
/// faixa, que dura minutos, nao faz diferenca.
List<EventoCicloEntity> eventosDeAlarme(
  List<HistoricoLeituraEntity> leituras, {
  List<EventoCicloEntity> existentes = const [],
  int cicloId = 0,
  Duration mesmoEpisodio = const Duration(minutes: 5),
}) {
  final ordenadas = [...leituras]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (ordenadas.length < 2) return [];

  bool jaRegistrado(DateTime quando, bool Function(String tipo) doTipo) {
    return existentes.any(
      (e) =>
          doTipo(e.tipo) &&
          e.timestamp.difference(quando).abs() <= mesmoEpisodio,
    );
  }

  final eventos = <EventoCicloEntity>[];
  var anterior = ordenadas.first.alertaIncendio;
  for (final leitura in ordenadas.skip(1)) {
    final atual = leitura.alertaIncendio;
    if (atual && !anterior) {
      final fogo = _ehFogo(leitura.aviso);
      if (!jaRegistrado(leitura.timestamp, _ehInicioDeAlarme)) {
        eventos.add(
          _evento(
            leitura,
            cicloId: cicloId,
            tipo: fogo ? 'alerta_incendio' : 'alarme_processo',
            severidade: fogo ? 'critico' : 'alerta',
            descricao: fogo
                ? 'Alerta de incêndio acionado.'
                : 'Alarme acionado: ${_textoDoAviso(leitura.aviso)}.',
          ),
        );
      }
    } else if (!atual && anterior) {
      if (!jaRegistrado(leitura.timestamp, (t) => t == 'alarme_normalizado')) {
        eventos.add(
          _evento(
            leitura,
            cicloId: cicloId,
            tipo: 'alarme_normalizado',
            severidade: 'info',
            descricao: 'Alarme normalizado.',
          ),
        );
      }
    }
    anterior = atual;
  }
  return eventos;
}

bool _ehInicioDeAlarme(String tipo) =>
    tipo == 'alarme_processo' || tipo == 'alerta_incendio';

// Os avisos do aparelho: "Sensor de chama ativado" e "Risco de incendio" sao
// fogo; "Temperatura alta/baixa" e o alarme de processo.
bool _ehFogo(String aviso) {
  final texto = aviso.toLowerCase();
  return texto.contains('chama') ||
      texto.contains('incêndio') ||
      texto.contains('incendio') ||
      texto.contains('fogo');
}

// O mesmo acabamento que o app da ao aviso no evento que ele grava.
String _textoDoAviso(String aviso) {
  final texto = aviso
      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
      .replaceAll('Temp ', 'Temperatura ')
      .trim();
  return texto.isEmpty ? 'temperatura fora da faixa' : texto;
}

EventoCicloEntity _evento(
  HistoricoLeituraEntity leitura, {
  required int cicloId,
  required String tipo,
  required String severidade,
  required String descricao,
}) {
  return EventoCicloEntity()
    ..ipEstufa = leitura.ipEstufa
    ..nomeEstufa = leitura.nomeEstufa
    ..cicloId = cicloId
    ..timestamp = leitura.timestamp
    ..tipo = tipo
    ..severidade = severidade
    ..descricao = descricao
    ..valorAtual = leitura.temperatura;
}
