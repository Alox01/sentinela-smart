
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/convite_estufa.dart';
import '../models/link_convite.dart';

/// Entrega a outro celular da familia o que ele precisa para acompanhar e
/// comandar esta estufa.
///
/// ## So o QR, e por que o texto saiu
///
/// Houve tambem um convite escrito, para quem estava longe. Foi retirado por
/// decisao do produtor: convite mandado por mensagem **fica gravado na
/// conversa**, com a chave da estufa dentro, para sempre — e a chave e do
/// APARELHO, quem a tiver comanda. Apagar do proprio celular nao apaga do outro
/// nem do backup dele. O QR nao fica gravado em conversa nenhuma.
///
/// O preco disso esta declarado: **compartilhar passou a exigir estar junto**.
/// Quem esta longe nao tem mais caminho, e nao ha rede de seguranca se a camera
/// do outro celular nao reconhecer o codigo.
///
/// **Nao confundir com "nao sobra copia em lugar nenhum"**, que seria mentira: o
/// Android tira um instantaneo desta tela para a lista de Recentes, com o QR
/// desenhado nele, e nada aqui impede print nem gravacao. Cumprir aquilo exigiria
/// FLAG_SECURE por MethodChannel.
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
              'Não foi possível montar o QR deste convite.',
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
                  'Quem tem a chave comanda a estufa de qualquer lugar, pela '
                  'internet — não só dentro da sua rede. Mande só para quem '
                  'pode.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'O QR não fica gravado em conversa nenhuma — é por isso que '
                  'ele é o único caminho: convite mandado por mensagem ficaria '
                  'guardado com a chave dentro, e apagar do seu celular não '
                  'apagaria do outro.',
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
