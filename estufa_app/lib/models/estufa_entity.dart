import 'package:isar/isar.dart';

part 'estufa_entity.g.dart';

@collection
class EstufaEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String chave;

  late String nome;
  late String ip;
  String? tokenAcesso;
  late DateTime criadaEm;
}
