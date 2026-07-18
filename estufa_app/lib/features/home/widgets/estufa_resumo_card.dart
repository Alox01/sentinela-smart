import 'package:flutter/material.dart';

import '../../../screens/monitoramento_screen.dart';
import '../../../services/monitor_estufas.dart';
import '../models/modelo_estufa.dart';

class EstufaResumoCard extends StatefulWidget {
  final ModeloEstufa estufa;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  const EstufaResumoCard({
    super.key,
    required this.estufa,
    required this.onEditar,
    required this.onRemover,
  });

  @override
  State<EstufaResumoCard> createState() => _EstufaResumoCardState();
}

class _EstufaResumoCardState extends State<EstufaResumoCard> {
  // Mesmo limiar da tela de monitoramento: no modo nuvem, uma leitura velha
  // demais significa que o aparelho parou de reportar (sem luz ou sem internet).
  static const int _limiarSemComunicacaoMs = 3 * 60 * 1000;

  late EstufaMonitor _monitor;

  @override
  void initState() {
    super.initState();
    _monitor = _obterMonitor();
    _monitor.assinar(_aoMudar);
  }

  @override
  void didUpdateWidget(covariant EstufaResumoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estufa.ip != widget.estufa.ip ||
        oldWidget.estufa.tokenAcesso != widget.estufa.tokenAcesso ||
        oldWidget.estufa.idHardware != widget.estufa.idHardware) {
      _monitor.desassinar(_aoMudar);
      _monitor = _obterMonitor();
      _monitor.assinar(_aoMudar);
    }
  }

  @override
  void dispose() {
    _monitor.desassinar(_aoMudar);
    super.dispose();
  }

  EstufaMonitor _obterMonitor() => MonitorEstufas.instance.obter(
    idEstufa: widget.estufa.id,
    ip: widget.estufa.ip,
    token: widget.estufa.tokenAcesso,
    idHardware: widget.estufa.idHardware,
  );

  void _aoMudar() {
    if (mounted) setState(() {});
  }

  // So vale no modo nuvem: em LOCAL, ter recebido a leitura ja prova que o
  // aparelho esta vivo agora.
  bool _semComunicacao(LeituraAoVivo leitura) {
    if (!leitura.temDados || leitura.modoConexao != 'NUVEM') return false;
    final status = leitura.dados!['status'];
    final tsLeitura = status is Map
        ? (status['timestampLeitura'] as num?)?.toInt()
        : null;
    if (tsLeitura == null) return false;
    return (DateTime.now().millisecondsSinceEpoch - tsLeitura) >
        _limiarSemComunicacaoMs;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MonitoramentoScreen(
                idEstufa: widget.estufa.id,
                nomeEstufa: widget.estufa.nome,
                ipEstufa: widget.estufa.ip,
                tokenAcesso: widget.estufa.tokenAcesso,
                idHardware: widget.estufa.idHardware,
              ),
            ),
          );
          // Nao precisa buscar ao voltar: as duas telas compartilham o mesmo
          // monitor, entao o card ja esta com a leitura mais recente.
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              _buildConteudoResumo(),
              Positioned(top: 6, right: 6, child: _buildMenuAcoes()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudoResumo() {
    final leitura = _monitor.ultima;
    // Enquanto a 1a resposta nao chega o card fica neutro: dizer "offline"
    // antes de ter tentado fazia todos os galpoes piscarem vermelho ao abrir.
    if (leitura == null) return _buildLayoutSemDados(false);
    if (!leitura.temDados) return _buildLayoutSemDados(true);

    final dados = leitura.dados!;
    final status = dados['status'] ?? {};
    final temp = double.parse((status['temperaturaAtual'] ?? 0).toString());
    final umid = double.parse((status['umidadeAtual'] ?? 0).toString());
    final sireneLigada =
        status['alarmeAtivo'] ?? status['alertaIncendio'] ?? false;
    final temAlerta = sireneLigada || (status['corStatus'] == 'red');

    return _buildLayoutOnline(temp, umid, temAlerta, _semComunicacao(leitura));
  }

  Widget _buildMenuAcoes() {
    return PopupMenuButton<String>(
      tooltip: 'A\u00E7\u00F5es da estufa',
      padding: EdgeInsets.zero,
      splashRadius: 16,

      color: const Color(0xFF252830),
      onSelected: (value) {
        if (value == 'editar') {
          widget.onEditar();
        } else if (value == 'remover') {
          widget.onRemover();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'editar',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'remover',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Remover'),
            ],
          ),
        ),
      ],
      child: const SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: Icon(Icons.more_vert, color: Colors.white70, size: 16),
        ),
      ),
    );
  }

  Widget _buildLayoutOnline(
    double temp,
    double umid,
    bool temAlerta,
    bool semComunicacao,
  ) {
    // Sem comunicacao: os valores sao a ultima leitura conhecida, nao o agora.
    final corLed = semComunicacao
        ? Colors.orangeAccent
        : (temAlerta ? Colors.redAccent : const Color(0xFF00FF00));
    return Stack(
      children: [
        Positioned(
          bottom: 4,
          right: 4,
          child: Icon(
            temAlerta ? Icons.warning_amber_rounded : Icons.warehouse_rounded,
            size: 24,
            color: temAlerta
                ? Colors.red.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // Nome pode ocupar duas linhas; o led acompanha a primeira.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: corLed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: corLed.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Text(
                        widget.estufa.nome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildInfoColumn(
                          'TEMPERATURA',
                          temp.toStringAsFixed(0),
                          '°F',
                          Colors.orangeAccent,
                        ),
                        const SizedBox(width: 15),
                        Container(width: 1, height: 30, color: Colors.white10),
                        const SizedBox(width: 15),
                        _buildInfoColumn(
                          'UMIDADE',
                          umid.toStringAsFixed(0),
                          '%',
                          Colors.lightBlueAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (semComunicacao)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SEM SINAL',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(
    String label,
    String valor,
    String unidade,
    Color corTitulo,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: corTitulo,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: valor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: unidade,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutSemDados(bool offline) {
    final cor = offline ? Colors.redAccent : Colors.white38;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(
                    widget.estufa.nome,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: offline
                  ? const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white24,
                      size: 34,
                    )
                  : const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white24,
                      ),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              offline ? 'OFFLINE' : 'CONECTANDO',
              style: TextStyle(
                color: cor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
