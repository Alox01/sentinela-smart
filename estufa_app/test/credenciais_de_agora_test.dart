import 'package:estufa_app/features/home/models/modelo_estufa.dart';
import 'package:estufa_app/features/home/services/estufas_repository.dart';
import 'package:estufa_app/features/monitoramento/credenciais_de_agora.dart';
import 'package:estufa_app/services/isar_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// O defeito que custou uma tarde: revogar o acesso gravava a chave nova no
/// banco, mas a tela de monitoramento continuava com a copia que recebeu da
/// lista. Todo comando virava "Chave invalida", inclusive na rede local.
void main() {
  // `MonitorEstufas.obter` registra um observador de ciclo de vida.
  TestWidgetsFlutterBinding.ensureInitialized();

  const idEstufa = 4001;

  test('chave trocada no banco vence a copia que a tela recebeu', () async {
    final repositorio = _RepositorioFalso([
      const ModeloEstufa(
        id: idEstufa,
        nome: 'Estufa 1',
        ip: 'sentinela-215788.local',
        tokenAcesso: 'chave-nova',
        idHardware: 'ESP32_215788',
      ),
    ]);

    final resultado = await credenciaisDeAgora(
      idEstufa: idEstufa,
      ipEmUso: 'sentinela-215788.local',
      tokenEmUso: 'chave-velha',
      idHardwareEmUso: 'ESP32_215788',
      repositorio: repositorio,
    );

    expect(
      resultado,
      isNotNull,
      reason: 'a chave mudou no banco: a tela precisa saber',
    );
    expect(resultado!.estufa.tokenAcesso, 'chave-nova');
    // O que de fato falhava em campo: o ApiService continuava com a chave morta.
    expect(
      resultado.monitor.api.authToken,
      'chave-nova',
      reason: 'o monitor tem de falar com o aparelho usando a chave de agora',
    );
  });

  test('nada mudou: segue com o monitor que ja esta em uso', () async {
    final repositorio = _RepositorioFalso([
      const ModeloEstufa(
        id: idEstufa + 1,
        nome: 'Estufa 1',
        ip: 'sentinela-215788.local',
        tokenAcesso: 'chave-igual',
        idHardware: 'ESP32_215788',
      ),
    ]);

    final resultado = await credenciaisDeAgora(
      idEstufa: idEstufa + 1,
      ipEmUso: 'sentinela-215788.local',
      tokenEmUso: 'chave-igual',
      idHardwareEmUso: 'ESP32_215788',
      repositorio: repositorio,
    );

    // Devolver monitor novo aqui derrubaria a leitura ao vivo a cada abertura
    // de tela, sem nenhum ganho.
    expect(resultado, isNull);
  });

  test('endereco editado tambem conta, nao so a chave', () async {
    final repositorio = _RepositorioFalso([
      const ModeloEstufa(
        id: idEstufa + 2,
        nome: 'Estufa 1',
        ip: 'sentinela-999999.local',
        tokenAcesso: 'chave-igual',
        idHardware: 'ESP32_215788',
      ),
    ]);

    final resultado = await credenciaisDeAgora(
      idEstufa: idEstufa + 2,
      ipEmUso: 'sentinela-215788.local',
      tokenEmUso: 'chave-igual',
      idHardwareEmUso: 'ESP32_215788',
      repositorio: repositorio,
    );

    expect(resultado, isNotNull);
    expect(resultado!.estufa.ip, 'sentinela-999999.local');
  });

  test('estufa que sumiu do banco nao derruba a tela aberta', () async {
    final repositorio = _RepositorioFalso(const []);

    final resultado = await credenciaisDeAgora(
      idEstufa: idEstufa + 3,
      ipEmUso: 'sentinela-215788.local',
      tokenEmUso: 'chave-velha',
      idHardwareEmUso: 'ESP32_215788',
      repositorio: repositorio,
    );

    // Removida em outro lugar enquanto esta tela estava aberta: quem fecha a
    // tela e o fluxo de remocao, nao esta releitura.
    expect(resultado, isNull);
  });
}

class _RepositorioFalso extends EstufasRepository {
  _RepositorioFalso(this._estufas) : super(IsarService.instance);

  final List<ModeloEstufa> _estufas;

  @override
  Future<ModeloEstufa?> buscar(int id) async {
    for (final estufa in _estufas) {
      if (estufa.id == id) return estufa;
    }
    return null;
  }
}
