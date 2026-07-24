import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/ciclo_secagem_entity.dart';

class EstufadaAtualCard extends StatelessWidget {
  final CicloSecagemEntity? ciclo;
  final VoidCallback onIniciar;
  final VoidCallback onFinalizar;
  final VoidCallback onAbrirRelatorio;

  const EstufadaAtualCard({
    super.key,
    required this.ciclo,
    required this.onIniciar,
    required this.onFinalizar,
    required this.onAbrirRelatorio,
  });

  @override
  Widget build(BuildContext context) {
    final temCiclo = ciclo != null;
    final formato = DateFormat('dd/MM HH:mm');
    final inicioTexto = temCiclo
        ? 'Iniciada em ${formato.format(ciclo!.inicio)}'
        : 'Nenhuma estufada em andamento';
    final apoioTexto = temCiclo
        ? 'Leituras registradas nesta estufada.'
        : 'Inicie quando colocar fumo verde na estufa.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2129),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final telaEstreita = constraints.maxWidth < 430;
          final conteudo = telaEstreita
              ? _EstufadaAtualMobile(
                  temCiclo: temCiclo,
                  inicioTexto: inicioTexto,
                  apoioTexto: apoioTexto,
                  onPressed: temCiclo ? onFinalizar : onIniciar,
                )
              : _EstufadaAtualDesktop(
                  temCiclo: temCiclo,
                  inicioTexto: inicioTexto,
                  apoioTexto: apoioTexto,
                  onPressed: temCiclo ? onFinalizar : onIniciar,
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              conteudo,
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, thickness: 1, height: 1),
              const SizedBox(height: 12),
              _BotaoRelatorioInterno(onPressed: onAbrirRelatorio),
            ],
          );
        },
      ),
    );
  }
}

class _EstufadaAtualMobile extends StatelessWidget {
  final bool temCiclo;
  final String inicioTexto;
  final String apoioTexto;
  final VoidCallback onPressed;

  const _EstufadaAtualMobile({
    required this.temCiclo,
    required this.inicioTexto,
    required this.apoioTexto,
    required this.onPressed,
  });

  // Tudo centralizado e o botao numa linha propria. Com o texto e o botao lado
  // a lado, "Nenhuma estufada em andamento" quebrava em duas linhas espremidas
  // contra o botao, e o card misturava tres alinhamentos (titulo centrado,
  // status a esquerda, apoio centrado). Ocupando a largura, o botao ainda vira
  // um alvo bem maior - o que conta para quem mexe nisso de luva.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TituloEstufadaAtual(textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Text(
          inicioTexto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          apoioTexto,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(
            temCiclo ? Icons.flag_rounded : Icons.play_arrow_rounded,
            size: 18,
          ),
          label: Text(temCiclo ? 'Finalizar' : 'Iniciar'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _EstufadaAtualDesktop extends StatelessWidget {
  final bool temCiclo;
  final String inicioTexto;
  final String apoioTexto;
  final VoidCallback onPressed;

  const _EstufadaAtualDesktop({
    required this.temCiclo,
    required this.inicioTexto,
    required this.apoioTexto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TituloEstufadaAtual(),
              const SizedBox(height: 4),
              Text(
                inicioTexto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                apoioTexto,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(temCiclo ? Icons.flag_rounded : Icons.play_arrow_rounded),
          label: Text(temCiclo ? 'Finalizar' : 'Iniciar'),
        ),
      ],
    );
  }
}

class _BotaoRelatorioInterno extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotaoRelatorioInterno({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.history, color: Colors.white70, size: 18),
        label: const Text('VER RELAT\u00D3RIOS DAS ESTUFADAS'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _TituloEstufadaAtual extends StatelessWidget {
  final TextAlign? textAlign;

  const _TituloEstufadaAtual({this.textAlign});

  @override
  Widget build(BuildContext context) {
    return Text(
      'ESTUFADA E RELAT\u00D3RIO',
      textAlign: textAlign,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
