import 'package:isar/isar.dart';

part 'historico_leitura_entity.g.dart';

@collection
class HistoricoLeituraEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late String ipEstufa;

  late String nomeEstufa;
  late DateTime timestamp;
  late double temperatura;
  late double umidade;
  late double temperaturaMeta;
  late double umidadeMeta;
  late String aviso;
  late bool alertaIncendio;
}
