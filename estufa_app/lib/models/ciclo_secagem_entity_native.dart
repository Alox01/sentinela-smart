import 'package:isar/isar.dart';

part 'ciclo_secagem_entity_native.g.dart';

@collection
class CicloSecagemEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late String ipEstufa;

  late String nomeEstufa;
  late DateTime inicio;
  DateTime? fim;
  late String status;
  late String observacao;
}
