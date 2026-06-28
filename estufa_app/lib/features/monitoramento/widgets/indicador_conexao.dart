import 'package:flutter/material.dart';

class IndicadorConexao extends StatelessWidget {
  final String modoConexao;
  final bool sincronizando;
  final int pendencias;

  const IndicadorConexao({
    super.key,
    required this.modoConexao,
    required this.sincronizando,
    required this.pendencias,
  });

  @override
  Widget build(BuildContext context) {
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;
    final modo = sincronizando ? 'SINCRONIZANDO' : modoConexao;
    final cor = switch (modo) {
      'LOCAL' => Colors.greenAccent,
      'NUVEM' => Colors.lightBlueAccent,
      'SINCRONIZANDO' => Colors.amberAccent,
      _ => Colors.redAccent,
    };
    final textoPendencias = pendencias > 0 ? ' | $pendencias' : '';

    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cor.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              modo == 'OFFLINE'
                  ? Icons.wifi_off_rounded
                  : modo == 'SINCRONIZANDO'
                  ? Icons.sync_rounded
                  : Icons.wifi_rounded,
              color: cor,
              size: telaEstreita ? 11 : 13,
            ),
            const SizedBox(width: 4),
            Text(
              '$modo$textoPendencias',
              style: TextStyle(
                color: cor,
                fontSize: telaEstreita ? 9 : 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
