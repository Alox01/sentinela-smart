import 'dart:async';
import 'package:flutter/material.dart';

class PainelControle extends StatelessWidget {
  // Faixa aceita pelo servidor (ver validacao em estufa_server/sync.js).
  // Manter alinhado para o ajuste nao ser recusado com 400.
  static const double temperaturaMinima = 60;
  static const double temperaturaMaxima = 200;

  final Function(double) onMudarTemperatura;
  final Function(double) onMudarUmidade;
  final double tempAjuste;
  final double umidAjuste;

  const PainelControle({
    super.key,
    required this.onMudarTemperatura,
    required this.onMudarUmidade,
    required this.tempAjuste,
    required this.umidAjuste,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2129),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'AJUSTE DE TEMPERATURA\nE UMIDADE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildControleCard(
                    "TEMPERATURA\n(${String.fromCharCode(176)}F)",
                    tempAjuste,
                    () {
                      if (tempAjuste < temperaturaMaxima) {
                        onMudarTemperatura(
                          (tempAjuste + 1)
                              .clamp(temperaturaMinima, temperaturaMaxima)
                              .toDouble(),
                        );
                      }
                    },
                    () {
                      if (tempAjuste > temperaturaMinima) {
                        onMudarTemperatura(
                          (tempAjuste - 1)
                              .clamp(temperaturaMinima, temperaturaMaxima)
                              .toDouble(),
                        );
                      }
                    },
                    Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControleCard(
                    "UMIDADE\n(%)",
                    umidAjuste,
                    () {
                      if (umidAjuste < 100) onMudarUmidade(umidAjuste + 1);
                    },
                    () {
                      if (umidAjuste > 0) onMudarUmidade(umidAjuste - 1);
                    },
                    Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildControleCard(
    String titulo,
    double valor,
    VoidCallback onMais,
    VoidCallback onMenos,
    Color corDestaque,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101215),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: corDestaque,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BotaoContinuo(icon: Icons.remove, onAction: onMenos),
              const SizedBox(width: 8),
              _BotaoContinuo(icon: Icons.add, onAction: onMais),
            ],
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

// Agora LedItem pode ser usado em outras telas.
class LedItem extends StatelessWidget {
  final String label;
  final bool isAtivo;
  final Color cor;

  const LedItem({
    super.key,
    required this.label,
    required this.isAtivo,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isAtivo ? cor : const Color(0xFF2A2D35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: 1.0),
            boxShadow: isAtivo
                ? [
                    BoxShadow(
                      color: cor.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isAtivo ? Colors.white : Colors.grey,
              fontSize: 11,
              fontWeight: isAtivo ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BotaoContinuo extends StatefulWidget {
  final IconData icon;
  final VoidCallback onAction;
  const _BotaoContinuo({required this.icon, required this.onAction});
  @override
  State<_BotaoContinuo> createState() => _BotaoContinuoState();
}

class _BotaoContinuoState extends State<_BotaoContinuo> {
  Timer? _timer;
  bool _isPressed = false;

  void _iniciarLoop() {
    setState(() => _isPressed = true);
    widget.onAction();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      widget.onAction();
    });
  }

  void _pararLoop() {
    setState(() => _isPressed = false);
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _iniciarLoop(),
        onTapUp: (_) => _pararLoop(),
        onTapCancel: () => _pararLoop(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isPressed
                ? const Color(0xFF3A3E4A)
                : const Color(0xFF252830),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isPressed ? Colors.white30 : Colors.white12,
            ),
            boxShadow: [
              if (!_isPressed)
                const BoxShadow(
                  color: Colors.black38,
                  offset: Offset(2, 2),
                  blurRadius: 3,
                ),
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
