import 'dart:async';
import 'package:flutter/material.dart';

import '../features/monitoramento/limites_ajuste.dart';

class PainelControle extends StatelessWidget {
  // O teto de verdade e do aparelho (ALVO_MAXIMO_F no firmware); aqui ele
  // existe para a tela nao oferecer o que o aparelho vai recusar. Ver
  // limites_ajuste.dart.
  static const double temperaturaMinima = ajusteTemperaturaMinimoF;
  static const double temperaturaMaxima = ajusteTemperaturaMaximoF;

  final Function(double) onMudarTemperatura;
  final Function(double) onMudarUmidade;
  final double tempAjuste;
  final double umidAjuste;

  /// Falso enquanto o app nao sabe em que ajuste a estufa esta: nunca leu este
  /// aparelho, e nao ha leitura guardada de sessao nenhuma.
  ///
  /// Nesse estado os botoes mostravam 0 e aceitavam toque. Um toque em + nao
  /// pedia "um grau acima do que esta la": pedia ajuste de 1 degF, a partir do
  /// zero de partida da tela - e o pedido ia para a fila e era aplicado na volta
  /// da internet. Ajustar sem conexao continua valendo e e proposital; o que
  /// nao pode e ajustar a partir de um numero que o app inventou.
  final bool baseConhecida;

  const PainelControle({
    super.key,
    required this.onMudarTemperatura,
    required this.onMudarUmidade,
    required this.tempAjuste,
    required this.umidAjuste,
    this.baseConhecida = true,
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

          if (!baseConhecida)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Sem leitura deste aparelho ainda: o ajuste aparece quando '
                'ele responder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),

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
              // Traco, nao zero: zero e um ajuste possivel de umidade, e como
              // temperatura era um numero que o produtor podia acreditar.
              baseConhecida ? valor.toStringAsFixed(0) : '--',
              style: TextStyle(
                color: baseConhecida ? Colors.white : Colors.white24,
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
              BotaoContinuo(
                icon: Icons.remove,
                onAction: onMenos,
                habilitado: baseConhecida,
              ),
              const SizedBox(width: 8),
              BotaoContinuo(
                icon: Icons.add,
                onAction: onMais,
                habilitado: baseConhecida,
              ),
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

/// Botao de + / - que **repete enquanto segurado**, um passo a cada 200 ms.
///
/// Publico porque a tela de agendamento usa o mesmo: o produtor ja aprendeu a
/// segurar para andar depressa no ajuste, e um seletor que so anda de um em um
/// toque seria um segundo jeito de fazer a mesma coisa.
class BotaoContinuo extends StatefulWidget {
  final IconData icon;
  final VoidCallback onAction;
  final bool habilitado;
  const BotaoContinuo({
    super.key,
    required this.icon,
    required this.onAction,
    this.habilitado = true,
  });
  @override
  State<BotaoContinuo> createState() => _BotaoContinuoState();
}

class _BotaoContinuoState extends State<BotaoContinuo> {
  Timer? _timer;
  bool _isPressed = false;

  void _iniciarLoop() {
    if (!widget.habilitado) return;
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
          child: Icon(
            widget.icon,
            color: widget.habilitado ? Colors.white : Colors.white24,
            size: 24,
          ),
        ),
      ),
    );
  }
}
