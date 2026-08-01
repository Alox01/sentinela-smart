import 'package:flutter/material.dart';

/// Itens informativos do menu da estufa.
///
/// Saíram de `monitoramento_screen` porque não dependem de nada que a tela faz:
/// recebem um valor e desenham. A tela ficou com 1.543 linhas e 45 métodos, e é
/// onde mais defeito de campo apareceu nesta semana — cada pedaço que só lê um
/// valor sai daqui em diante.
///
/// O que continua na tela é o que mexe em estado: silenciar avisos, agendar,
/// reconfigurar.

/// Cabeçalho de seção do menu.
class TituloMenu extends StatelessWidget {
  final String texto;

  const TituloMenu(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Diz se ESTE celular será avisado sobre ESTA estufa.
///
/// Uma estufa que não está inscrita para avisos é IDÊNTICA a uma inscrita, na
/// tela. Foi assim que um aparelho ficou 24 h fora do ar sem nenhum aviso sair,
/// e só apareceu ao olhar o banco da nuvem.
class ItemVigilancia extends StatelessWidget {
  /// `null` = ainda conferindo. `false` = não está inscrita.
  final bool? vigiada;

  /// Sem id não há a quem amarrar o aviso, e o conserto é outro — por isso a
  /// mensagem separa os dois casos.
  final bool semIdHardware;

  const ItemVigilancia({
    super.key,
    required this.vigiada,
    required this.semIdHardware,
  });

  @override
  Widget build(BuildContext context) {
    final (titulo, legenda, cor) = switch (vigiada) {
      true => (
        'Avisos no celular: ativos',
        'Este celular é avisado se algo acontecer com esta estufa.',
        Colors.white70,
      ),
      false when semIdHardware => (
        'Avisos no celular: NÃO ativos',
        'Esta estufa ainda não sabe de qual aparelho é, então não há como '
            'avisar. Conecte-se a ela na rede local uma vez, ou informe o ID '
            'no cadastro.',
        Colors.orangeAccent,
      ),
      false => (
        'Avisos no celular: NÃO ativos',
        'Não consegui inscrever este celular. Abra o app com internet para '
            'tentar de novo.',
        Colors.orangeAccent,
      ),
      null => ('Avisos no celular', 'Conferindo...', Colors.white38),
    };

    return ListTile(
      leading: Icon(
        vigiada == false
            ? Icons.notifications_off_outlined
            : Icons.notifications_active_outlined,
        color: cor,
      ),
      title: Text(titulo, style: TextStyle(color: cor)),
      subtitle: Text(
        legenda,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}

/// Estado REAL da sirene daquele aparelho, como ele reporta.
///
/// Informativo, não ação: a troca é no aparelho, segurando o botão 3 s. Existe
/// porque o interruptor global da tela de notificações é uma ordem para todos os
/// aparelhos, e não um espelho de cada um — dois podem estar diferentes, e só
/// aqui dá para saber qual é qual.
class ItemSireneDoAparelho extends StatelessWidget {
  /// `null` = o aparelho ainda não informou.
  final bool? ativa;

  const ItemSireneDoAparelho({super.key, required this.ativa});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // Mesmo ícone do cartão "Alarme dos aparelhos" na tela de notificações: é
      // o mesmo assunto, então ícones diferentes sugeririam coisas diferentes.
      // Não muda com o estado, que já está escrito no título (e não existe
      // variante "campaign off" no Material).
      leading: const Icon(Icons.campaign_outlined, color: Colors.white70),
      title: Text(
        ativa == null
            ? 'Sirene do aparelho'
            : 'Sirene do aparelho: ${ativa! ? 'ligada' : 'desligada'}',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        ativa == null
            ? 'Aguardando o aparelho informar'
            : 'Para ligar e desligar, segure o botão do alarme no aparelho '
                  'por 3 s.',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}
