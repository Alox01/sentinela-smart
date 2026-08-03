import 'package:estufa_app/features/home/models/convite_estufa.dart';
import 'package:estufa_app/features/home/models/link_convite.dart';
import 'package:flutter_test/flutter_test.dart';

/// O endereco que vai dentro do QR.
///
/// O risco desta area e silencioso: um convite que vira endereco, entra no QR,
/// e volta pela camera **diferente do que saiu**. Ninguem ve isso na tela — a
/// estufa so nao responde depois, no outro celular, longe daqui.
///
/// Dai os testes serem quase todos de ida e volta, e um deles afirmar
/// caractere a caractere que o alfabeto do convite atravessa a URL intacto.
void main() {
  const convite = ConviteEstufa(
    nome: 'Estufa do Fundo',
    endereco: 'sentinela-215788.local',
    chave: 'chave-longa-do-aparelho',
    idHardware: 'ESP32_215788',
  );

  test('o convite volta inteiro depois de virar endereço', () {
    final lido = LinkConvite.ler(Uri.parse(LinkConvite.montar(convite)));

    expect(lido, isNotNull);
    expect(lido!.nome, convite.nome);
    expect(lido.endereco, convite.endereco);
    expect(lido.chave, convite.chave);
    expect(lido.idHardware, convite.idHardware);
  });

  test('o endereço tem a forma que o AndroidManifest espera', () {
    final endereco = Uri.parse(LinkConvite.montar(convite));

    // Se qualquer um dos tres mudar, o intent-filter para de casar e o Android
    // deixa de oferecer o app — falha calada, que so aparece com o QR na mao.
    expect(endereco.scheme, 'sentinela');
    expect(endereco.host, 'convite');
    expect(endereco.queryParameters.keys, ['c']);
  });

  // A rede de seguranca: leitor de QR que so MOSTRA o texto deixa quem recebeu
  // com o convite na tela, para copiar e colar. Isso so funciona se o texto do
  // endereco contiver a marca legivel, sem escape.
  test('a marca sobrevive dentro do endereço, sem escape', () {
    final texto = LinkConvite.montar(convite);

    expect(texto, contains('SENTINELA1:'));
    expect(texto, isNot(contains('%')));
    // O decodificador de sempre acha o convite no meio do endereco, do mesmo
    // jeito que acha no meio de uma conversa.
    expect(ConviteEstufa.decodificar(texto)?.chave, convite.chave);
  });

  test('o parâmetro chega ao decodificador sem um caractere trocado', () {
    final endereco = Uri.parse(LinkConvite.montar(convite));

    expect(endereco.queryParameters['c'], convite.codificar());
  });

  // Duas perguntas diferentes, e o nulo de `ler` respondia as duas de uma vez:
  // "isto nao era para nos" e "era para nos e nao deu para ler". Quem recebe
  // precisa distinguir — a primeira pede silencio, a segunda pede aviso.
  group('reconhece o endereço como nosso antes de ler o conteúdo', () {
    test('convite bom é nosso', () {
      expect(
        LinkConvite.enderecoDeConvite(Uri.parse(LinkConvite.montar(convite))),
        isTrue,
      );
    });

    test('convite estragado continua sendo nosso', () {
      // O caso do app antigo lendo convite de formato novo: o endereco casou o
      // intent-filter, o Android abriu o Sentinela, e so o conteudo falhou.
      final endereco = Uri.parse('sentinela://convite?c=bom%20dia');

      expect(LinkConvite.enderecoDeConvite(endereco), isTrue);
      expect(LinkConvite.ler(endereco), isNull);
    });

    test('endereço nosso sem o parâmetro continua sendo nosso', () {
      expect(
        LinkConvite.enderecoDeConvite(Uri.parse('sentinela://convite')),
        isTrue,
      );
    });

    test('outro esquema não é nosso', () {
      expect(
        LinkConvite.enderecoDeConvite(Uri.parse('https://convite?c=x')),
        isFalse,
      );
    });

    test('outro assunto no mesmo esquema não é nosso', () {
      expect(
        LinkConvite.enderecoDeConvite(Uri.parse('sentinela://ajuste?c=x')),
        isFalse,
      );
    });

    test('nenhum endereço não é nosso', () {
      expect(LinkConvite.enderecoDeConvite(null), isFalse);
    });
  });

  group('endereço que não é convite nosso é recusado', () {
    test('outro esquema', () {
      expect(LinkConvite.ler(Uri.parse('https://convite?c=x')), isNull);
    });

    test('outro assunto no mesmo esquema', () {
      final corpo = convite.codificar();
      expect(LinkConvite.ler(Uri.parse('sentinela://ajuste?c=$corpo')), isNull);
    });

    test('sem o parâmetro', () {
      expect(LinkConvite.ler(Uri.parse('sentinela://convite')), isNull);
    });

    test('com o parâmetro cheio de lixo', () {
      expect(LinkConvite.ler(Uri.parse('sentinela://convite?c=bom%20dia')),
          isNull);
    });

    test('nenhum endereço', () {
      expect(LinkConvite.ler(null), isNull);
    });
  });

  // O Android normaliza `esquema://maquina` para host, mas um endereco digitado
  // ou reescrito por outro app pode chegar como `esquema:maquina`, onde o mesmo
  // texto vira caminho. Aceitar so uma das formas daria uma falha que nao
  // aparece em lugar nenhum ate estar no aparelho.
  test('aceita o convite mesmo quando vem como caminho, não como host', () {
    final corpo = convite.codificar();
    final lido = LinkConvite.ler(Uri.parse('sentinela:convite?c=$corpo'));

    expect(lido?.idHardware, 'ESP32_215788');
  });

  // Sem chave o convite ainda serve (estufa sem chave configurada), e e
  // justamente o caso em que um campo a menos poderia passar despercebido.
  test('convite sem chave nem id atravessa igual', () {
    const magro = ConviteEstufa(nome: 'Estufa 2', endereco: '192.168.0.50');
    final lido = LinkConvite.ler(Uri.parse(LinkConvite.montar(magro)));

    expect(lido?.nome, 'Estufa 2');
    expect(lido?.endereco, '192.168.0.50');
    expect(lido?.chave, isNull);
    expect(lido?.idHardware, isNull);
  });
}
