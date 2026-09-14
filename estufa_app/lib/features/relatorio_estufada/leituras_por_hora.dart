import '../../models/historico_leitura_entity.dart';

/// As leituras que entram na tabela do PDF: a primeira de cada hora do relogio,
/// mais a ultima da estufada.
///
/// Com o historico da nuvem a estufada tem uma leitura a cada 10 minutos. Uma
/// secagem de uma semana dava mil linhas, e o papel virava uma lista que
/// ninguem le. O que acontece entre uma hora e outra ja esta na tabela de
/// eventos, logo acima, com o horario certo.
///
/// Uma excecao: a leitura em que o alarme liga ou desliga entra sempre, mesmo
/// fora da virada da hora. A coluna "Alarme" da tabela nao pode perder o
/// momento em que ele mudou.
///
/// So a TABELA e afinada. O resumo do PDF e o CSV continuam com todas as
/// leituras.
List<HistoricoLeituraEntity> leiturasPorHora(
  List<HistoricoLeituraEntity> leituras,
) {
  if (leituras.length <= 2) return leituras;

  final ordenadas = [...leituras]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final resultado = <HistoricoLeituraEntity>[];
  DateTime? horaDaUltima;
  bool? alarmeAnterior;
  for (final leitura in ordenadas) {
    final t = leitura.timestamp;
    final hora = DateTime(t.year, t.month, t.day, t.hour);
    final alarmeMudou =
        alarmeAnterior != null && leitura.alertaIncendio != alarmeAnterior;
    if (hora != horaDaUltima || alarmeMudou) {
      resultado.add(leitura);
      horaDaUltima = hora;
    }
    alarmeAnterior = leitura.alertaIncendio;
  }

  if (!identical(resultado.last, ordenadas.last)) {
    resultado.add(ordenadas.last);
  }
  return resultado;
}
