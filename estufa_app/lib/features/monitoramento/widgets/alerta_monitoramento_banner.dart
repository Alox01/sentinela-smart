import 'package:flutter/material.dart';

class AlertaMonitoramentoBanner extends StatelessWidget {
  final bool incendioDetectado;
  final double temperaturaAtual;
  final String avisoEmergencia;

  const AlertaMonitoramentoBanner({
    super.key,
    required this.incendioDetectado,
    required this.temperaturaAtual,
    required this.avisoEmergencia,
  });

  @override
  Widget build(BuildContext context) {
    final alertaCritico = incendioDetectado || temperaturaAtual >= 175.0;

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
