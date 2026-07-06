import 'package:flutter/material.dart';

import '../../../widgets/card_sensor.dart';
import '../../../widgets/painel_controle.dart';

class LeituraAparelhoCard extends StatelessWidget {
  final double temperatura;
  final double umidade;
  final double temperaturaAjuste;
  final double umidadeAjuste;
  final bool sireneLigada;
  final bool temperaturaEmAcomodacao;
  final bool umidadeEmAcomodacao;
  final VoidCallback onSilenciarAlarme;

  const LeituraAparelhoCard({
    super.key,
    required this.temperatura,
    required this.umidade,
    required this.temperaturaAjuste,
    required this.umidadeAjuste,
    required this.sireneLigada,
    this.temperaturaEmAcomodacao = false,
    this.umidadeEmAcomodacao = false,
    required this.onSilenciarAlarme,
  });

  // Acende com 5 de diferenca do ajuste. Durante a acomodacao (logo apos mudar
  // o ajuste), so o nivel critico (20) acende, para nao confundir a estufa
  // "perseguindo" o novo alvo com uma oscilacao de clima.
  static double _limiarLed(bool emAcomodacao) => emAcomodacao ? 20.0 : 5.0;

  @override
  Widget build(BuildContext context) {
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;
    final alturaCardsLeitura = telaEstreita ? 170.0 : 150.0;
    final fonteValorLeitura = telaEstreita ? 40.0 : null;

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
        children: [
          const _TituloLeitura(),
          const SizedBox(height: 18),
          SizedBox(
            height: alturaCardsLeitura,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CardSensor(
                    titulo: 'TEMPERATURA\nATUAL',
                    valor: '${temperatura.toStringAsFixed(0)}\u00B0F',
                    icone: Icons.thermostat,
                    cor: Colors.orange,
                    valorFontSize: fonteValorLeitura,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: CardSensor(
                    titulo: 'UMIDADE\nATUAL',
                    valor: '${umidade.toStringAsFixed(0)}%',
                    icone: Icons.water_drop,
                    cor: Colors.blueAccent,
                    valorFontSize: fonteValorLeitura,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, thickness: 1),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AlarmeStatus(
                      sireneLigada: sireneLigada,
                      onSilenciar: onSilenciarAlarme,
                    ),
                  ),
                  const VerticalDivider(color: Colors.white10, thickness: 1),
                  Expanded(
                    child: _IndicadoresGrandeza(
                      titulo: 'TEMPERATURA',
                      icone: Icons.thermostat,
                      corIcone: Colors.orangeAccent,
                      alta: temperatura >
                          temperaturaAjuste + _limiarLed(temperaturaEmAcomodacao),
                      baixa: temperatura <
                          temperaturaAjuste - _limiarLed(temperaturaEmAcomodacao),
                    ),
                  ),
                  const VerticalDivider(color: Colors.white10, thickness: 1),
                  Expanded(
                    child: _IndicadoresGrandeza(
                      titulo: 'UMIDADE',
                      icone: Icons.water_drop,
                      corIcone: Colors.lightBlueAccent,
                      alta: umidade >
                          umidadeAjuste + _limiarLed(umidadeEmAcomodacao),
                      baixa: umidade <
                          umidadeAjuste - _limiarLed(umidadeEmAcomodacao),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloLeitura extends StatelessWidget {
  const _TituloLeitura();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'LEITURA DO APARELHO',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AlarmeStatus extends StatelessWidget {
  final bool sireneLigada;
  final VoidCallback onSilenciar;

  const _AlarmeStatus({required this.sireneLigada, required this.onSilenciar});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 13,
              ),
              SizedBox(width: 4),
              Text(
                'ALARME',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: sireneLigada
                ? Colors.red.withValues(alpha: 0.15)
                : const Color(0xFF252830),
            shape: BoxShape.circle,
            border: Border.all(
              color: sireneLigada
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : Colors.white12,
              width: 1.0,
            ),
          ),
          child: IconButton(
            iconSize: 32,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
            icon: Icon(
              sireneLigada
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: sireneLigada ? Colors.redAccent : Colors.white38,
            ),
            onPressed: onSilenciar,
          ),
        ),
      ],
    );
  }
}

class _IndicadoresGrandeza extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Color corIcone;
  final bool alta;
  final bool baixa;

  const _IndicadoresGrandeza({
    required this.titulo,
    required this.icone,
    required this.corIcone,
    required this.alta,
    required this.baixa,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, color: corIcone, size: 13),
              const SizedBox(width: 4),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Bloco centralizado, mas com os leds alinhados a esquerda entre si:
        // sem isso, "Alta" (mais curta) fica com o led deslocado em relacao
        // ao led de "Baixa".
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LedItem(label: 'Alta', isAtivo: alta, cor: Colors.orangeAccent),
            const SizedBox(height: 8),
            LedItem(label: 'Baixa', isAtivo: baixa, cor: Colors.cyanAccent),
          ],
        ),
      ],
    );
  }
}
