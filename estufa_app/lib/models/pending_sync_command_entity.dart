import 'package:isar/isar.dart';

part 'pending_sync_command_entity.g.dart';

@collection
class PendingSyncCommandEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late String ipEstufa;

  late String payloadJson;
  late DateTime createdAt;
}
