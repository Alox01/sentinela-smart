import 'package:flutter/material.dart';

Future<bool> confirmarFinalizacaoEstufada(BuildContext context) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E2129),
      title: const Text(
        'Finalizar estufada?',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Use esta op\u00E7\u00E3o quando o fumo j\u00E1 saiu curado da estufa. O relat\u00F3rio ficar\u00E1 fechado com as leituras desse per\u00EDodo.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Finalizar'),
        ),
      ],
    ),
  );

  return confirmar == true;
}

Future<bool> confirmarSugestaoFimEstufada(BuildContext context) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E2129),
      title: const Text(
        'A estufada terminou?',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'O ajuste de temperatura caiu para abaixo de 100\u00B0F depois de trabalhar alto. Isso pode indicar o fim da cura. Deseja finalizar esta estufada?',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Agora n\u00E3o'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Finalizar'),
        ),
      ],
    ),
  );

  return confirmar == true;
}

Future<bool> confirmarLimpezaPendencias(BuildContext context) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E2129),
      title: const Text(
        'Limpar comandos pendentes?',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Use isso quando a fila ficou presa ou quando voc\u00EA quer descartar comandos antigos. Os ajustes atuais do servidor n\u00E3o ser\u00E3o alterados.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Limpar'),
        ),
      ],
    ),
  );

  return confirmar == true;
}
