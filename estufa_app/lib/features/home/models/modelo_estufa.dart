import '../../../models/estufa_entity.dart';

class ModeloEstufa {
  final int id;
  final String nome;
  final String ip;
  final String? tokenAcesso;
  final String? idHardware;

  const ModeloEstufa({
    required this.id,
    required this.nome,
    required this.ip,
    this.tokenAcesso,
    this.idHardware,
  });

  factory ModeloEstufa.fromEntity(EstufaEntity entity) {
    return ModeloEstufa(
      id: entity.id,
      nome: entity.nome,
      ip: entity.ip,
      tokenAcesso: entity.tokenAcesso,
      idHardware: entity.idHardware,
    );
  }
}
