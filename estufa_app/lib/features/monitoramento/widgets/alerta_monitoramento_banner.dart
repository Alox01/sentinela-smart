import 'package:flutter/material.dart';

import '../limiar_incendio.dart';

class AlertaMonitoramentoBanner extends StatelessWidget {
  final bool incendioDetectado;
  final double temperaturaAtual;

  /// O ajuste em vigor. Sem ele nao da para saber onde comeca o fogo: o limite
  /// acompanha o ajuste quando ele passa de 170 (ver [limiteFogoF]).
  final double temperaturaAjuste;
  final String avisoEmergencia;

  const AlertaMonitoramentoBanner({
    super.key,
    required this.incendioDetectado,
    required this.temperaturaAtual,
    required this.temperaturaAjuste,
    required this.avisoEmergencia,
  });

  @override
  Widget build(BuildContext context) {
    // Era `>= 175.0`, cravado. O aparelho e o servidor ja seguiam o ajuste, e
    // este banner nao: numa cura com ajuste em 180, os dois ficavam quietos ate
    // 185 enquanto a tela pintava emergencia em vermelho desde 175 — com a
    // estufa fazendo exatamente o que foi mandada fazer.
    final alertaCritico =
        incendioDetectado || temperaturaAtual >= limiteFogoF(temperaturaAjuste);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertaCritico ? const Color(0xFFFF453A) : Colors.deepOrange,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: alertaCritico
                ? Colors.redAccent.withValues(alpha: 0.5)
                : Colors.deepOrangeAccent.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _textoAlerta().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _textoAlerta() {
    if (incendioDetectado) return avisoEmergencia;
    if (temperaturaAtual >= 175.0) return 'RISCO DE INCENDIO! (>175°F)';
    return 'ALERTA: SUPERAQUECIMENTO (>165°F)';
  }
}
