import 'package:flutter/foundation.dart';

import '../../services/monitor_estufas.dart';
import '../home/models/modelo_estufa.dart';
import '../home/services/estufas_repository.dart';

/// A estufa relida do banco e o monitor que fala com ela.
@immutable
class CredenciaisDeAgora {
  final ModeloEstufa estufa;
  final EstufaMonitor monitor;

  const CredenciaisDeAgora({required this.estufa, required this.monitor});
}

/// Confere no banco se a estufa ainda e o que a tela recebeu, e devolve um
/// monitor com os dados de agora quando nao e. `null` significa "nada mudou,
/// siga com o que ja tem" — inclusive quando a estufa sumiu do banco.
///
/// Existe porque a interface entrega a estufa por copia: a lista le do banco, o
/// card recebe da lista, a tela recebe do card. Trocar a chave grava no banco e
/// nao em nenhuma dessas copias, e o `MonitorEstufas` entao comparava a chave
/// velha com a velha, concluia "nao mudou" e reusava o `ApiService` morto. Todo
/// comando virava "Chave invalida", **inclusive na rede local com o aparelho ao
/// lado**, ate o app ser reiniciado.
///
/// Relendo aqui, nenhum lugar da interface precisa estar em dia com o banco: a
/// copia velha se conserta sozinha ao abrir a tela.
Future<CredenciaisDeAgora?> credenciaisDeAgora({
  required int idEstufa,
  required String ipEmUso,
  required String? tokenEmUso,
  required String? idHardwareEmUso,
  required EstufasRepository repositorio,
}) async {
  final estufa = await repositorio.buscar(idEstufa);
  if (estufa == null) return null;

  final igual = estufa.ip == ipEmUso
      && estufa.tokenAcesso == tokenEmUso
      && estufa.idHardware == idHardwareEmUso;
  if (igual) return null;

  return CredenciaisDeAgora(
    estufa: estufa,
    monitor: MonitorEstufas.instance.obter(
      idEstufa: idEstufa,
      ip: estufa.ip,
      token: estufa.tokenAcesso,
      idHardware: estufa.idHardware,
    ),
  );
}
