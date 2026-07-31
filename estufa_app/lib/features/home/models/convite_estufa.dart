import 'dart:convert';

/// Convite para outro celular da familia acompanhar e comandar a mesma estufa.
///
/// Existe porque a chave e do APARELHO, nao do celular: qualquer celular que a
/// tenha comanda. O que faltava era o segundo celular receber a chave sem entrar
/// no modo de configuracao — que derruba o aparelho do ar enquanto dura, e no
/// meio de uma estufada isso e caro.
///
/// Quem ja tem acesso pode delegar: e a familia, nao um estranho. O convite
/// carrega o que o cadastro precisa e nada mais.
class ConviteEstufa {
  /// Marca a versao do formato. Um convite de formato desconhecido e recusado em
  /// vez de interpretado pela metade — meio cadastro e pior que nenhum.
  static const String _marca = 'SENTINELA1';

  final String nome;
  final String endereco;
  final String? chave;
  final String? idHardware;

  const ConviteEstufa({
    required this.nome,
    required this.endereco,
    this.chave,
    this.idHardware,
  });

  /// Texto para o produtor mandar por onde ja conversa com a familia.
  ///
  /// Vai em base64 de proposito: nao para esconder (nao esconde de ninguem), mas
  /// para viajar inteiro. Texto cru com a chave no meio convida a "corrigir"
  /// espaco e quebra de linha pelo caminho, e a chave chega diferente.
  String codificar() {
    final dados = jsonEncode({
      'v': 1,
      'nome': nome,
      'ip': endereco,
      if (chave != null && chave!.isNotEmpty) 'chave': chave,
      if (idHardware != null && idHardware!.isNotEmpty) 'id': idHardware,
    });
    return '$_marca:${base64Url.encode(utf8.encode(dados))}';
  }

  /// Le um convite colado. Devolve nulo quando o texto nao e um convite — o que
  /// inclui o caso comum de colar qualquer outra coisa por engano.
  static ConviteEstufa? decodificar(String texto) {
    final limpo = texto.trim();
    // O texto pode chegar com sobras da conversa em volta; interessa o pedaco
    // que comeca na marca.
    final inicio = limpo.indexOf('$_marca:');
    if (inicio < 0) return null;
    final corpo = limpo.substring(inicio + _marca.length + 1).split(RegExp(r'\s'))
        .first;
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(corpo)));
      if (json is! Map) return null;
      if (json['v'] != 1) return null;
      final nome = json['nome']?.toString().trim() ?? '';
      final ip = json['ip']?.toString().trim() ?? '';
      if (nome.isEmpty || ip.isEmpty) return null;
      final chave = json['chave']?.toString();
      final id = json['id']?.toString();
      return ConviteEstufa(
        nome: nome,
        endereco: ip,
        chave: (chave != null && chave.isNotEmpty) ? chave : null,
        idHardware: (id != null && id.isNotEmpty) ? id : null,
      );
    } catch (_) {
      return null;
    }
  }
}
