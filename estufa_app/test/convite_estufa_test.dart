import 'package:estufa_app/features/home/models/convite_estufa.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chave e do aparelho, nao do celular: qualquer celular que a tenha comanda.
/// O convite serve para o segundo celular receber a chave sem entrar no modo de
/// configuracao, que derrubaria o aparelho do ar enquanto durasse.
void main() {
  const convite = ConviteEstufa(
    nome: 'Estufa do Fundo',
    endereco: 'sentinela-215788.local',
    chave: 'chave-longa-do-aparelho',
    idHardware: 'ESP32_215788',
  );

  test('o convite volta inteiro', () {
    final lido = ConviteEstufa.decodificar(convite.codificar());
    expect(lido, isNotNull);
    expect(lido!.nome, convite.nome);
    expect(lido.endereco, convite.endereco);
    expect(lido.chave, convite.chave);
    expect(lido.idHardware, convite.idHardware);
  });

  // Convites viajam dentro de conversa: chegam com texto em volta.
  test('acha o convite no meio de uma mensagem', () {
    final texto = 'Oi pai, entra ai ó: ${convite.codificar()} valeu';
    final lido = ConviteEstufa.decodificar(texto);
    expect(lido?.idHardware, 'ESP32_215788');
  });

  test('texto que nao e convite devolve nulo', () {
    expect(ConviteEstufa.decodificar('bom dia'), isNull);
    expect(ConviteEstufa.decodificar(''), isNull);
  });

  // Meio cadastro e pior que nenhum: sem endereco nada funciona depois.
  test('convite sem endereco e recusado', () {
    const semEndereco = ConviteEstufa(nome: 'Estufa', endereco: '');
    expect(ConviteEstufa.decodificar(semEndereco.codificar()), isNull);
  });

  test('formato desconhecido e recusado em vez de adivinhado', () {
    expect(ConviteEstufa.decodificar('SENTINELA1:naoEhBase64Valido!!'), isNull);
  });
}
