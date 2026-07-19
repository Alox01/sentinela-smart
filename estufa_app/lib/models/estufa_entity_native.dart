import 'package:isar/isar.dart';

part 'estufa_entity_native.g.dart';

@collection
class EstufaEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String chave;

  late String nome;
  late String ip;
  String? tokenAcesso;
  // Identificador do aparelho na nuvem (capturado na 1a conexao local, do
  // /status do ESP). Deixa cada estufa puxar o SEU estado remoto por aparelho.
  String? idHardware;
  late DateTime criadaEm;
}
