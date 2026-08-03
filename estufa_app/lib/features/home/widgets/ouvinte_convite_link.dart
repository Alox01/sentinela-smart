import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../models/convite_estufa.dart';
import '../models/link_convite.dart';

/// Escuta os enderecos que o sistema entrega ao app e avisa quando um deles e
/// um convite de estufa.
///
/// ## Por que nao um leitor de QR dentro do app
///
/// Ler QR pela camera exigiria plugin nativo e permissao de camera. Este
/// projeto ja apanhou de plugin nativo — um obrigou a forcar o `compileSdk` no
/// Gradle, outro quebrou por causa de link simbolico no Windows — e uma
/// permissao de camera pedida por um app de estufa e uma pergunta que o produtor
/// nao deveria ter de responder.
///
/// O caminho escolhido nao tem leitor nenhum: o QR carrega um endereco
/// `sentinela://convite?c=...`, quem recebe aponta a **camera normal** do
/// celular, e o proprio Android oferece abrir o Sentinela. Todo o custo fica num
/// `intent-filter` no `AndroidManifest.xml` e neste ouvinte.
///
/// ## Por que a fonte dos enderecos e injetavel
///
/// [enderecos] existe para o teste. O caminho de verdade — camera, Android,
/// intent — nao cabe em teste automatizado, mas o que este widget faz **com** o
/// endereco cabe: calar diante do que nao e nosso, avisar quando e nosso e
/// chegou estragado, e nao abrir dois cadastros ao mesmo tempo. Sem a costura,
/// essa parte so seria conferida com dois celulares na mao.
class OuvinteConviteLink extends StatefulWidget {
  final Widget child;

  /// Chamado uma vez por convite valido recebido.
  final Future<void> Function(ConviteEstufa convite) aoReceber;

  /// Nulo = a fonte de verdade, o `app_links`.
  final Stream<Uri>? enderecos;

  const OuvinteConviteLink({
    super.key,
    required this.child,
    required this.aoReceber,
    this.enderecos,
  });

  @override
  State<OuvinteConviteLink> createState() => _OuvinteConviteLinkState();
}

class _OuvinteConviteLinkState extends State<OuvinteConviteLink> {
  StreamSubscription<Uri>? _assinatura;

  /// Um convite de cada vez. O celular ja apontado para o QR dispara com
  /// facilidade duas leituras seguidas, e dois formularios empilhados fazem o
  /// produtor cadastrar a mesma estufa duas vezes — que e justamente o estado
  /// que o cadastro tenta impedir (duas estufas no mesmo endereco passam a
  /// mostrar os dados do mesmo aparelho).
  bool _atendendo = false;

  @override
  void initState() {
    super.initState();
    // O `app_links` guarda o endereco que abriu o app e o entrega na primeira
    // escuta, entao assinar aqui — depois do banco local estar de pe — nao
    // perde o convite que veio da partida a frio.
    final fonte = widget.enderecos ?? AppLinks().uriLinkStream;
    _assinatura = fonte.listen(
      _aoChegar,
      // Endereco malformado nao e motivo para derrubar o app: quem errou foi
      // quem mandou, e o produtor nem sabe que existe um endereco no meio.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    unawaited(_assinatura?.cancel());
    super.dispose();
  }

  Future<void> _aoChegar(Uri endereco) async {
    if (_atendendo || !mounted) return;

    // O app pode ser acordado por endereco que nao e nosso. Ai nao ha nada a
    // fazer e nada a dizer: o produtor nao pediu isto, e um erro na tela so o
    // assustaria.
    if (!LinkConvite.enderecoDeConvite(endereco)) return;

    // Daqui para baixo ele PEDIU: apontou a camera, o Android ofereceu o
    // Sentinela e ele tocou. Calar agora e deixa-lo com um app que abriu e nao
    // fez nada — sem mensagem, sem pista, e no celular de outra pessoa. Vai
    // acontecer: `decodificar` recusa de proposito formato que nao conhece,
    // entao um celular com app antigo lendo convite de formato novo cai
    // exatamente aqui.
    final convite = LinkConvite.ler(endereco);
    if (convite == null) {
      // O mesmo aviso do "Colar convite", pela mesma razao: o conserto e o
      // mesmo, e duas frases para a mesma situacao acabam divergindo.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(ConviteEstufa.avisoIlegivel),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    _atendendo = true;
    try {
      await widget.aoReceber(convite);
    } finally {
      _atendendo = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
