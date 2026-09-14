import '../../models/evento_ciclo_entity.dart';
import '../../models/historico_leitura_entity.dart';

/// Os eventos de "ajuste alterado" do relatorio, tirados das LEITURAS.
///
/// Ate 14/09/2026 eles nasciam no app, na hora de mandar o comando, e isso
/// errava de dois jeitos (`AUDITORIA.md`, D7):
///
/// - **mudanca feita nos botoes do aparelho nao aparecia** — nem a feita por
///   outro celular, nem a do agendamento, nem nada que acontecesse com o app
///   fechado. O relatorio contava a historia do app, e o aparelho e a fonte da
///   verdade;
/// - **mexer no app com pausas virava uma rajada** — "75", "76", "80", "85" no
///   mesmo minuto, uma linha por pausa de 1 s do produtor.
///
/// Toda leitura carrega o ajuste que o aparelho reportava naquela hora — e a
/// nuvem grava uma leitura sempre que o ajuste muda. Entao a historia do ajuste
/// ja esta nas leituras, venha a mudanca de onde vier.
///
/// Mudancas a menos de [juntarDentroDe] uma da outra viram UMA linha, do valor
/// de antes da primeira ao de depois da ultima, no horario da primeira. Ir e
/// voltar ao mesmo valor nao vira linha nenhuma: nada mudou.
///
/// [temAjuste] tira da conta as leituras que nao trazem o ajuste (leitura
/// antiga da nuvem, em que ele vem preenchido com a propria leitura) — elas
/// inventariam uma mudanca a cada ponto.
List<EventoCicloEntity> eventosDeAjuste(
  List<HistoricoLeituraEntity> leituras, {
  int cicloId = 0,
  bool Function(HistoricoLeituraEntity leitura)? temAjuste,
  Duration juntarDentroDe = const Duration(minutes: 5),
}) {
  final validas = [
    for (final leitura in leituras)
      if (temAjuste == null || temAjuste(leitura)) leitura,
  ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (validas.length < 2) return [];

  final eventos = [
    ..._mudancas(
      validas,
      (l) => l.temperaturaMeta,
      cicloId: cicloId,
      tipo: 'ajuste_temperatura',
      grandeza: 'temperatura',
      unidade: '°F',
      janela: juntarDentroDe,
    ),
    ..._mudancas(
      validas,
      (l) => l.umidadeMeta,
      cicloId: cicloId,
      tipo: 'ajuste_umidade',
      grandeza: 'umidade',
      unidade: '%',
      janela: juntarDentroDe,
    ),
  ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return eventos;
}

/// Uma mudanca em andamento: de onde saiu, onde esta, quando comecou.
class _Mudanca {
  final double de;
  final DateTime inicio;
  final HistoricoLeituraEntity leitura;
  double para;
  DateTime ultima;

  _Mudanca({
    required this.de,
    required this.para,
    required this.inicio,
    required this.leitura,
  }) : ultima = inicio;
}

List<EventoCicloEntity> _mudancas(
  List<HistoricoLeituraEntity> leituras,
  double Function(HistoricoLeituraEntity) valorDe, {
  required int cicloId,
  required String tipo,
  required String grandeza,
  required String unidade,
  required Duration janela,
}) {
  final eventos = <EventoCicloEntity>[];
  _Mudanca? aberta;

  void fechar() {
    final mudanca = aberta;
    aberta = null;
    if (mudanca == null || _igual(mudanca.de, mudanca.para)) return;
    final de = mudanca.de.toStringAsFixed(0);
    final para = mudanca.para.toStringAsFixed(0);
    eventos.add(
      EventoCicloEntity()
        ..ipEstufa = mudanca.leitura.ipEstufa
        ..nomeEstufa = mudanca.leitura.nomeEstufa
        ..cicloId = cicloId
        ..timestamp = mudanca.inicio
        ..tipo = tipo
        ..severidade = 'info'
        ..descricao = 'Ajuste de $grandeza alterado de $de para $para$unidade.'
        ..valorAnterior = mudanca.de
        ..valorAtual = mudanca.para,
    );
  }

  var anterior = valorDe(leituras.first);
  for (final leitura in leituras.skip(1)) {
    final valor = valorDe(leitura);
    final mudanca = aberta;
    if (mudanca != null &&
        leitura.timestamp.difference(mudanca.ultima) > janela) {
      fechar();
    }
    if (!_igual(valor, anterior)) {
      final atual = aberta;
      if (atual == null) {
        aberta = _Mudanca(
          de: anterior,
          para: valor,
          inicio: leitura.timestamp,
          leitura: leitura,
        );
      } else {
        atual
          ..para = valor
          ..ultima = leitura.timestamp;
      }
    }
    anterior = valor;
  }
  fechar();
  return eventos;
}

// O ajuste e inteiro no aparelho; meio grau de diferenca e ruido de conversao.
bool _igual(double a, double b) => (a - b).abs() < 0.5;
