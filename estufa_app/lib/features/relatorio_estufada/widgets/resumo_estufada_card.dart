import 'package:flutter/material.dart';

class ResumoEstufadaCard extends StatelessWidget {
  final Duration duracao;
  final double temperaturaMetaInicial;
  final double temperaturaMetaFinal;
  final double umidadeMetaInicial;
  final double umidadeMetaFinal;
  final int totalAlarmes;
  final TextStyle tituloSecaoStyle;

  const ResumoEstufadaCard({
    super.key,
    required this.duracao,
    required this.temperaturaMetaInicial,
    required this.temperaturaMetaFinal,
    required this.umidadeMetaInicial,
    required this.umidadeMetaFinal,
    required this.totalAlarmes,
    required this.tituloSecaoStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RESUMO DA ESTUFADA',
            style: tituloSecaoStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ResumoCard(
                'DURA\u00C7\u00C3O',
                _formatarDuracao(duracao),
                Colors.white70,
              ),
              const SizedBox(width: 12),
              _ResumoCard(
                'TEMP. IN\u00CDCIO',
                '${temperaturaMetaInicial.toStringAsFixed(0)}\u00B0F',
                Colors.orangeAccent,
                subtitulo: 'Ajuste inicial',
              ),
              const SizedBox(width: 12),
              _ResumoCard(
                'TEMP. ATUAL',
                '${temperaturaMetaFinal.toStringAsFixed(0)}\u00B0F',
                Colors.orangeAccent,
                subtitulo: '\u00DAltimo ajuste',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ResumoCard(
                'ALARMES',
                '$totalAlarmes',
                totalAlarmes > 0 ? Colors.redAccent : Colors.greenAccent,
              ),
              const SizedBox(width: 12),
              _ResumoCard(
                'UMID. IN\u00CDCIO',
                '${umidadeMetaInicial.toStringAsFixed(0)}%',
                Colors.lightBlueAccent,
                subtitulo: 'Ajuste inicial',
              ),
              const SizedBox(width: 12),
              _ResumoCard(
                'UMID. ATUAL',
                '${umidadeMetaFinal.toStringAsFixed(0)}%',
                Colors.lightBlueAccent,
                subtitulo: '\u00DAltimo ajuste',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatarDuracao(Duration duracao) {
    final horas = duracao.inHours.toString().padLeft(2, '0');
    final minutos = duracao.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$horas:$minutos h';
  }
}

class _ResumoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final String? subtitulo;

  const _ResumoCard(this.titulo, this.valor, this.cor, {this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;

    return Expanded(
      child: Container(
        height: telaEstreita ? 104 : 86,
        padding: EdgeInsets.symmetric(
          horizontal: telaEstreita ? 8 : 12,
          vertical: telaEstreita ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              style: TextStyle(
                color: Colors.white38,
                fontSize: telaEstreita ? 9 : 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo ?? '',
              style: TextStyle(
                color: Colors.white30,
                fontSize: telaEstreita ? 8 : 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: telaEstreita ? 6 : 5),
            FittedBox(
              child: Text(
                valor,
                style: TextStyle(
                  color: cor,
                  fontSize: telaEstreita ? 18 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
