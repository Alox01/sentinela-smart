import 'package:isar/isar.dart';

part 'evento_ciclo_entity.g.dart';

@collection
class EventoCicloEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late String ipEstufa;

  @Index()
  late int cicloId;

  late String nomeEstufa;
  late DateTime timestamp;
  late String tipo;
  late String severidade;
  late String descricao;
  double? valorAnterior;
  double? valorAtual;
}
