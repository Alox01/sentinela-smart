import 'convite_estufa.dart';

/// O endereco que vai dentro do QR code do convite.
///
/// ## Por que um link, e nao o convite cru
///
/// O QR e para quem esta do lado. A forma barata de le-lo seria embutir um
/// leitor no app, mas isso traz plugin nativo e permissao de camera — e este
/// projeto ja apanhou de plugin nativo. Com um link de app, quem recebe aponta a
/// **camera normal** do celular: o Android reconhece o endereco, oferece abrir o
/// Sentinela, e ninguem instala leitor nenhum.
///
/// ## Por que a marca continua dentro do link
///
/// [ConviteEstufa.decodificar] procura o pedaco que comeca em `SENTINELA1:`.
/// Mandar so o base64 no parametro quebraria isso, e ajustar o decodificador
/// mexeria no caminho do "Colar convite", que ja esta testado e em campo. Entao
/// o parametro carrega a **string inteira** do convite, marca inclusive.
///
/// Isso paga um segundo bilhete: um leitor de QR que apenas *mostre* o texto
/// (em vez de abrir o app) deixa quem recebeu com o convite completo na tela,
/// para copiar e usar em "Colar convite". O caminho de texto continua servindo
/// de rede de seguranca para o caminho novo.
///
/// ## Por que nada aqui e escapado
///
/// O alfabeto do convite e `SENTINELA1:` mais base64 **url-safe** — letras,
/// digitos, `-`, `_` e `=` de enchimento. Nenhum deles precisa de escape numa
/// consulta (`:` e `=` sao validos ali pela RFC 3986), e nenhum e `+`, que o
/// Dart transformaria em espaco ao ler os parametros. Escapar geraria `%3A` no
/// texto exibido por um leitor simples e estragaria exatamente a rede de
/// seguranca descrita acima.
class LinkConvite {
  static const String esquema = 'sentinela';
  static const String maquina = 'convite';

  /// Nome do parametro. Curto de proposito: cada caractere a mais no QR o
  /// deixa mais denso, e QR denso e o que falha na camera tremida.
  static const String parametro = 'c';

  const LinkConvite._();

  /// `sentinela://convite?c=SENTINELA1:...`
  static String montar(ConviteEstufa convite) =>
      '$esquema://$maquina?$parametro=${convite.codificar()}';

  /// O endereco e ENDERECADO A NOS, mesmo que o conteudo esteja estragado.
  ///
  /// Separado de [ler] porque quem recebe precisa distinguir duas coisas que o
  /// nulo de [ler] confundia: "isto nao era para o Sentinela" — a que so cabe
  /// silencio — e "era para o Sentinela e nao deu para ler", em que alguem
  /// apontou a camera, tocou no que o Android ofereceu, e merece saber por que
  /// nada aconteceu.
  static bool enderecoDeConvite(Uri? endereco) {
    if (endereco == null) return false;
    if (endereco.scheme.toLowerCase() != esquema) return false;
    // O Android entrega `sentinela://convite?...` com "convite" no host, mas
    // basta o esquema mudar de forma (`sentinela:convite?...`) para ele virar
    // caminho. Aceitar os dois evita uma falha que so aparece no aparelho.
    final alvo = endereco.host.isNotEmpty
        ? endereco.host
        : endereco.path.replaceAll('/', '');
    return alvo.toLowerCase() == maquina;
  }

  /// Le o convite de um endereco recebido pelo sistema. Devolve nulo para
  /// qualquer coisa que nao seja um convite nosso — o app pode ser acordado por
  /// endereco de outra origem, e meio cadastro e pior que nenhum.
  static ConviteEstufa? ler(Uri? endereco) {
    if (!enderecoDeConvite(endereco)) return null;

    final bruto = endereco!.queryParameters[parametro];
    if (bruto == null) return null;
    return ConviteEstufa.decodificar(bruto);
  }
}
