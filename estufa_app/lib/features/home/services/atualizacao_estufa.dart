import 'estufas_repository.dart';

/// O que muda numa estufa JA cadastrada quando chegam chave e endereco novos
/// do mesmo aparelho.
///
/// ## Por que existe
///
/// Duas portas levam ao mesmo lugar, e as duas mexem no mesmo par de campos:
///
/// - o **modo de configuracao** (`UsoDaConfiguracao.atualizacao`), quando o
///   produtor gira a chave no proprio aparelho;
/// - o **convite** de quem ja tem a chave nova, quando a estufa daquele
///   aparelho ja esta cadastrada neste celular.
///
/// Cada porta calculando o proprio "mudou?" era o caminho curto para uma gravar
/// o que a outra recusa — e o campo em jogo e a chave, que gravada errada tira o
/// acesso do produtor ate ele ir ate o aparelho.
///
/// ## O que esta classe NAO faz
///
/// Nao pergunta nada. Confirmar e decisao de quem chama, porque as duas portas
/// chegam com autoridade diferente: no modo de configuracao o produtor acabou de
/// ler a chave do aparelho, com ele na mao; pelo convite, a chave vem de fora,
/// e ai a confirmacao e obrigatoria.
class AtualizacaoDeEstufa {
  final int id;

  /// O nome atual da estufa. Vai gravado de volta como esta: quem atualiza a
  /// chave nao esta pedindo para renomear, e o nome e escolha de cada celular.
  final String nome;

  final String endereco;
  final String? chave;
  final String? idHardware;

  final bool mudaChave;
  final bool mudaEndereco;

  const AtualizacaoDeEstufa._({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.chave,
    required this.idHardware,
    required this.mudaChave,
    required this.mudaEndereco,
  });

  /// Compara o que a estufa tem hoje com o que chegou. Devolve **nulo quando
  /// nada mudaria** — gravar por cima o mesmo valor nao e inofensivo: pede uma
  /// confirmacao sobre coisa nenhuma e anuncia uma atualizacao que nao houve.
  ///
  /// Valor novo ausente ou vazio significa "nao veio nada", nunca "apague o que
  /// esta la".
  static AtualizacaoDeEstufa? entre({
    required int id,
    required String nome,
    required String enderecoAtual,
    required String? chaveAtual,
    required String? idHardwareAtual,
    required String? enderecoNovo,
    required String? chaveNova,
    required String? idHardwareNovo,
  }) {
    final chave = _valor(chaveNova);
    final endereco = _valor(enderecoNovo);
    final mudaChave = chave != null && chave != _valor(chaveAtual);
    final mudaEndereco = endereco != null && endereco != _valor(enderecoAtual);
    if (!mudaChave && !mudaEndereco) return null;

    return AtualizacaoDeEstufa._(
      id: id,
      nome: nome,
      endereco: endereco ?? enderecoAtual,
      chave: chave ?? chaveAtual,
      // O id do aparelho nao entra na conta do "mudou?": ele e identidade, nao
      // configuracao. Mas segue junto para uma estufa cadastrada a mao, sem id,
      // aprender o dele agora — sem isso ela continuaria sem ler pela nuvem.
      idHardware: idHardwareNovo ?? idHardwareAtual,
      mudaChave: mudaChave,
      mudaEndereco: mudaEndereco,
    );
  }

  /// "a chave e o endereço", "a chave" ou "o endereço".
  ///
  /// Existe para a confirmacao dizer O QUE muda em vez de um "OK?" generico:
  /// quem le precisa poder recusar sabendo o que estava prestes a acontecer.
  String get oQueMuda {
    if (mudaChave && mudaEndereco) return 'a chave e o endereço';
    return mudaChave ? 'a chave' : 'o endereço';
  }

  Future<void> aplicar(EstufasRepository repositorio) => repositorio.atualizar(
    id: id,
    nome: nome,
    ip: endereco,
    tokenAcesso: chave,
    idHardware: idHardware,
  );

  static String? _valor(String? texto) {
    final limpo = texto?.trim() ?? '';
    return limpo.isEmpty ? null : limpo;
  }
}
