import 'package:flutter/material.dart';

class AdicionarEstufaCard extends StatelessWidget {
  final VoidCallback onTap;

  const AdicionarEstufaCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101215),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.add, color: Colors.white54, size: 24),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nova Estufa',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
