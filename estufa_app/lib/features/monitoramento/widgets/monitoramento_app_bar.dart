import 'package:flutter/material.dart';

import 'indicador_conexao.dart';

/// AppBar da tela de monitoramento: nome da estufa (com balao do nome completo),
/// indicador de conexao e acoes de detalhes/sincronizacao.
class MonitoramentoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String nomeEstufa;
  final String modoConexao;
  final bool sincronizando;
  final int pendencias;
  final VoidCallback onAbrirMenu;

  const MonitoramentoAppBar({
    super.key,
    required this.nomeEstufa,
    required this.modoConexao,
    required this.sincronizando,
    required this.pendencias,
    required this.onAbrirMenu,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;

    return AppBar(
      leading: IconButton(
        iconSize: 20,
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Voltar',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      // Titulo alinhado a esquerda: nomes longos ganham o espaco livre e
      // cortam com reticencias, em vez de encolher espremidos entre a seta
      // e o indicador de conexao.
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tocar no nome abreviado mostra o nome completo num balao, que
          // some ao tocar fora ou apos alguns segundos.
          Tooltip(
            message: nomeEstufa,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 3),
            preferBelow: true,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D35),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: Colors.white, fontSize: 13),
            child: Text(
              nomeEstufa.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: telaEstreita ? 15 : 17,
                letterSpacing: telaEstreita ? 0.6 : 1,
              ),
            ),
          ),
          Text(
            'MONITORAMENTO',
            maxLines: 1,
            style: TextStyle(
              fontSize: telaEstreita ? 9 : 12,
              color: Colors.white70,
              letterSpacing: telaEstreita ? 1.4 : 2,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1C1C1E),
      foregroundColor: Colors.white,
      centerTitle: false,
      titleSpacing: 0,
      elevation: 0,
      actions: [
        IndicadorConexao(
          modoConexao: modoConexao,
          sincronizando: sincronizando,
          pendencias: pendencias,
        ),
        IconButton(
          visualDensity: telaEstreita ? VisualDensity.compact : null,
          iconSize: telaEstreita ? 22 : 26,
          constraints: telaEstreita
              ? const BoxConstraints.tightFor(width: 36, height: 48)
              : null,
          onPressed: onAbrirMenu,
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Ações da estufa',
        ),
      ],
    );
  }
}
