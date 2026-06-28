import 'package:flutter/material.dart';

class RelatorioEstufadaButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RelatorioEstufadaButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.history, color: Colors.white),
        label: const Text('VER RELATÓRIO DA ESTUFADA'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF252830),
          foregroundColor: Colors.white,
          elevation: 0,
          side: const BorderSide(color: Colors.white10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
