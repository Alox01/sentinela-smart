import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/convite_estufa.dart';
import '../models/link_convite.dart';

/// Entrega a outro celular da familia o que ele precisa para acompanhar e
/// comandar esta estufa.
///
/// ## Por que duas formas, e nao uma
///
/// O QR **nao substitui** o texto: sao situacoes diferentes. O texto serve para
/// quem esta longe — o filho na cidade, o vizinho que cuida no fim de semana. O
/// QR serve para quem esta do lado, e faz em tres segundos o que pelo texto
/// pediria escolher aplicativo, achar a conversa e mandar.
///
/// ## A vantagem que so o QR tem
///
/// Convite mandado por mensagem **fica gravado na conversa**, com a chave da
/// estufa dentro, para sempre — e a chave e do APARELHO: quem a tiver comanda.
/// Apagar a mensagem do proprio celular nao apaga a do outro, nem o backup dela.
/// O QR aparece na tela, e sai da tela; nao sobra copia em lugar nenhum.
///
/// Isso esta dito na tela, e nao so aqui, porque quem compartilha e quem decide
/// — e a decisao acontece na hora de escolher entre os dois botoes.
class CompartilharAcessoScreen extends StatelessWidget {
  final ConviteEstufa convite;

  const CompartilharAcessoScreen({super.key, required this.convite});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191D),
        foregroundColor: Colors.white,
        title: const Text('Compartilhar acesso'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    convite.nome,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CartaoQr(convite: convite),
                  const SizedBox(height: 20),
                  _CartaoTexto(convite: convite),
                  const SizedBox(height: 18),
                  const _AvisoDaChave(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O caminho de quem esta do lado.
class _CartaoQr extends StatelessWidget {
  final ConviteEstufa convite;

  const _CartaoQr({required this.convite});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text(
            'QUEM ESTÁ DO SEU LADO',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          QrDoConvite(endereco: LinkConvite.montar(convite)),
          const SizedBox(height: 16),
          const Text(
            'Abra a câmera normal do outro celular e aponte para o código. '
            'Ele oferece abrir o Sentinela com a estufa já preenchida — não '
            'precisa instalar leitor nenhum.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// O quadrado em si.
///
/// Existe separado, e publico, por dois motivos. O primeiro e que ele carrega
/// uma regra: **fundo claro e faixa vazia em volta**. Nao sao enfeite — leitor
/// de QR precisa do contraste e da margem para achar o codigo, e sobre o fundo
/// escuro do app a leitura falha em boa parte dos celulares. Quem for reusar o
/// QR em outra tela leva a regra junto.
///
/// O segundo e que [QrImageView] guarda o dado num campo privado: ninguem
/// consegue perguntar a ele *qual* convite foi desenhado. Um QR com o convite
/// errado parece exatamente igual a um QR certo, e o erro so apareceria no
/// outro celular, depois. Este invólucro deixa o [endereco] visível para o
/// teste afirmar.
class QrDoConvite extends StatelessWidget {
  final String endereco;

  const QrDoConvite({super.key, required this.endereco});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: QrImageView(
        data: endereco,
        version: QrVersions.auto,
        size: 220,
        backgroundColor: Colors.white,
        // Se um dia o convite crescer a ponto de nao caber, isto diz o que
        // houve em vez de deixar um quadrado vazio na tela.
        errorStateBuilder: (context, erro) => const SizedBox(
          height: 220,
          child: Center(
            child: Text(
              'Não foi possível montar o QR deste convite. '
              'Use o envio por mensagem abaixo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

/// O caminho de quem esta longe. E o mesmo de antes do QR existir, com o mesmo
/// texto: quem ja recebeu convite assim continua achando o "Colar convite".
class _CartaoTexto extends StatelessWidget {
  final ConviteEstufa convite;

  const _CartaoTexto({required this.convite});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'QUEM ESTÁ LONGE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Manda o convite escrito. No outro celular: Nova Estufa e depois '
            '"Colar convite".',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => unawaited(_enviarTexto()),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Enviar por mensagem'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarTexto() async {
    // O aviso vai junto no texto, nao so na tela: quem recebe pode nao ser quem
    // leu a tela, e o convite carrega a chave da estufa.
    await Share.share(
      'Convite para acompanhar a estufa "${convite.nome}" no Sentinela.\n'
      'No app, toque em Nova Estufa e depois em "Colar convite".\n'
      'Mande só para quem pode comandar a estufa.\n\n'
      '${convite.codificar()}',
      subject: 'Acesso à estufa ${convite.nome}',
    );
  }
}

/// O que o produtor precisa saber antes de escolher entre os dois botoes acima.
class _AvisoDaChave extends StatelessWidget {
  const _AvisoDaChave();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key_outlined, color: Colors.orangeAccent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O convite carrega a chave da estufa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Quem tem a chave comanda a estufa. Mande só para quem pode.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'O QR não sai desta sala: aparece na tela e some. O convite '
                  'mandado por mensagem fica gravado na conversa, com a chave '
                  'dentro, para sempre — apagar do seu celular não apaga do '
                  'outro. Estando os dois juntos, prefira o QR.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
