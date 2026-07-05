import 'dart:async';

import 'package:flutter/material.dart';

import '../../../screens/monitoramento_screen.dart';
import '../../../services/api_service.dart';
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
  late ApiService _api;
  Timer? _timerResumo;
  Map<String, dynamic>? _dadosResumo;

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.estufa.ip, token: widget.estufa.tokenAcesso);
    unawaited(_atualizarResumo());
    _timerResumo = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _atualizarResumo(),
    );
  }

  @override
  void didUpdateWidget(covariant EstufaResumoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estufa.ip != widget.estufa.ip ||
        oldWidget.estufa.tokenAcesso != widget.estufa.tokenAcesso) {
      _api = ApiService(widget.estufa.ip, token: widget.estufa.tokenAcesso);
      _dadosResumo = null;
      unawaited(_atualizarResumo());
    }
  }

  @override
  void dispose() {
    _timerResumo?.cancel();
    super.dispose();
  }

  Future<void> _atualizarResumo() async {
    final dados = await _api.buscarStatus();
    if (!mounted) return;
    setState(() {
      _dadosResumo = dados;
    });
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
                nomeEstufa: widget.estufa.nome,
                ipEstufa: widget.estufa.ip,
                tokenAcesso: widget.estufa.tokenAcesso,
              ),
            ),
          ).then((_) => _atualizarResumo());
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
    final dados = _dadosResumo;
    if (dados == null) return _buildLayoutOffline();

    final status = dados['status'] ?? {};
    final temp = double.parse((status['temperaturaAtual'] ?? 0).toString());
    final umid = double.parse((status['umidadeAtual'] ?? 0).toString());
    final sireneLigada =
        status['alarmeAtivo'] ?? status['alertaIncendio'] ?? false;
    final temAlerta = sireneLigada || (status['corStatus'] == 'red');

    return _buildLayoutOnline(temp, umid, temAlerta);
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

  Widget _buildLayoutOnline(double temp, double umid, bool temAlerta) {
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
                        color: temAlerta
                            ? Colors.redAccent
                            : const Color(0xFF00FF00),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: temAlerta
                                ? Colors.redAccent.withValues(alpha: 0.6)
                                : Colors.greenAccent.withValues(alpha: 0.4),
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
                      padding: const EdgeInsets.only(right: 28),
                      child: Text(
                        widget.estufa.nome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.1,
                        ),
                        maxLines: 3,
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

  Widget _buildLayoutOffline() {
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
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.4),
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
                  padding: const EdgeInsets.only(right: 28),
                  child: Text(
                    widget.estufa.nome,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      height: 1.1,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const Expanded(
            child: Center(
              child: Icon(
                Icons.wifi_off_rounded,
                color: Colors.white24,
                size: 34,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'OFFLINE',
              style: TextStyle(
                color: Colors.redAccent,
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
