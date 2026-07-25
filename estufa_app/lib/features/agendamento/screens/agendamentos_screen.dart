import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/painel_controle.dart';
import '../models/agendamento_ajuste.dart';
import '../services/agendamento_service.dart';

/// Agenda um ajuste para mais tarde e lista o que ja esta marcado.
///
/// O caso que originou a tela: o produtor quer o ajuste em 120 °F daqui duas
/// horas, e nessa hora nao vai estar por perto.
class AgendamentosScreen extends StatefulWidget {
  final int idEstufa;
  final String nomeEstufa;
  final String? idHardware;
  final String? tokenAcesso;

  /// Ajustes vigentes, so para mostrar de onde o valor relativo vai partir.
  final double temperaturaAtual;
  final double umidadeAtual;

  const AgendamentosScreen({
    super.key,
    required this.idEstufa,
    required this.nomeEstufa,
    required this.idHardware,
    required this.tokenAcesso,
    required this.temperaturaAtual,
    required this.umidadeAtual,
  });

  @override
  State<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

class _AgendamentosScreenState extends State<AgendamentosScreen> {
  final _servico = AgendamentoService.instance;
  final _formato = DateFormat('dd/MM HH:mm');

  // Quanto tempo a partir de agora. Atalhos em vez de seletor de hora: o
  // produtor pensa em "daqui duas horas", nao em "as 16h13".
  static const List<int> _minutosAtalho = [30, 60, 120, 180, 360, 720];
  int _minutos = 120;

  // So valor absoluto: "deixe em 120 F". A variacao relativa existiu aqui e saiu
  // por ser um segundo jeito de dizer a mesma coisa, com a desvantagem de o
  // produtor ter de fazer a conta de cabeca para saber onde vai parar.
  double _tempAbsoluta = 120;
  bool _mexerUmidade = false;
  double _umidAbsoluta = 40;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_servico.carregar());
    // Abrir a tela e uma boa hora para tentar de novo: quem agendou sem sinal
    // costuma voltar aqui para conferir.
    unawaited(_servico.reenviarPendentes());
    // Comeca no ajuste que ja esta valendo: o produtor quase sempre quer mexer
    // a partir dali, entao ele so anda a diferenca em vez de montar o numero do
    // zero. Zero significa que a leitura ainda nao chegou - ai vale o padrao.
    if (widget.temperaturaAtual > 0) _tempAbsoluta = widget.temperaturaAtual;
    if (widget.umidadeAtual > 0) _umidAbsoluta = widget.umidadeAtual;
  }

  DateTime get _quando => DateTime.now().add(Duration(minutes: _minutos));

  Future<void> _salvar() async {
    final idHw = widget.idHardware;
    setState(() => _salvando = true);
    final agendamento = await _servico.criar(
      idEstufa: widget.idEstufa,
      nomeEstufa: widget.nomeEstufa,
      idHardware: idHw,
      tokenAcesso: widget.tokenAcesso,
      quando: _quando,
      temperaturaMeta: _tempAbsoluta,
      umidadeMeta: _mexerUmidade ? _umidAbsoluta : null,
    );
    if (!mounted) return;
    setState(() => _salvando = false);

    // Honesto sobre o alcance: sem registro na nuvem o aviso sai na hora, mas o
    // ajuste nao muda sozinho com o app fechado.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          agendamento.registradoNaNuvem
              ? 'Agendado para ${_formato.format(agendamento.quando)}.'
              : 'Aviso agendado. Sem internet agora, o ajuste será registrado '
                    'assim que o celular reconectar.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _cancelar(AgendamentoAjuste agendamento) async {
    await _servico.cancelar(agendamento, tokenAcesso: widget.tokenAcesso);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191D),
        foregroundColor: Colors.white,
        title: const Text('Agendar ajuste'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _servico,
          builder: (context, _) {
            final marcados = _servico.daEstufa(widget.idEstufa);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const Text(
                  'O celular avisa na hora marcada, mesmo sem internet, e o '
                  'ajuste muda sozinho pela nuvem.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 18),
                _cartaoQuando(),
                const SizedBox(height: 12),
                _cartaoOQue(),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : () => unawaited(_salvar()),
                    icon: const Icon(Icons.alarm_add_rounded, size: 18),
                    label: Text(_salvando ? 'Agendando...' : 'Agendar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (marcados.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const Text(
                    'JÁ AGENDADOS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final agendamento in marcados)
                    _linhaAgendado(agendamento),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cartao({required String titulo, required Widget filho}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        filho,
      ],
    ),
  );

  Widget _cartaoQuando() => _cartao(
    titulo: 'Quando',
    filho: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutos in _minutosAtalho)
              ChoiceChip(
                label: Text(_rotuloMinutos(minutos)),
                selected: _minutos == minutos,
                onSelected: (_) => setState(() => _minutos = minutos),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Vai avisar às ${_formato.format(_quando)}.',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    ),
  );

  static String _rotuloMinutos(int minutos) {
    if (minutos < 60) return '$minutos min';
    final horas = minutos ~/ 60;
    return horas == 1 ? '1 hora' : '$horas horas';
  }

  Widget _cartaoOQue() => _cartao(
    titulo: 'O que ajustar',
    filho: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'O ajuste vai ficar exatamente neste valor abaixo.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _seletorNumero(
          rotulo: 'Temperatura (°F)',
          valor: _tempAbsoluta,
          minimo: 60,
          maximo: 200,
          aoMudar: (v) => setState(() => _tempAbsoluta = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'Ajustar umidade também',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          value: _mexerUmidade,
          onChanged: (v) => setState(() => _mexerUmidade = v),
        ),
        if (_mexerUmidade)
          _seletorNumero(
            rotulo: 'Umidade (%)',
            valor: _umidAbsoluta,
            minimo: 0,
            maximo: 100,
            aoMudar: (v) => setState(() => _umidAbsoluta = v),
          ),
      ],
    ),
  );

  /// Mesmos botoes do painel de ajuste: seguram para andar depressa, um passo a
  /// cada 200 ms. O produtor ja conhece o gesto de la.
  Widget _seletorNumero({
    required String rotulo,
    required double valor,
    required double minimo,
    required double maximo,
    required ValueChanged<double> aoMudar,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          // O limite e aplicado aqui, e nao desabilitando o botao: segurando, o
          // valor simplesmente para na borda em vez de o toque morrer no meio.
          BotaoContinuo(
            icon: Icons.remove,
            onAction: () => aoMudar((valor - 1).clamp(minimo, maximo)),
          ),
          SizedBox(
            width: 64,
            child: Text(
              valor.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          BotaoContinuo(
            icon: Icons.add,
            onAction: () => aoMudar((valor + 1).clamp(minimo, maximo)),
          ),
        ],
      ),
    );
  }

  Widget _linhaAgendado(AgendamentoAjuste agendamento) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      children: [
        const Icon(Icons.schedule_rounded, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formato.format(agendamento.quando),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                agendamento.descricao,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (!agendamento.registradoNaNuvem)
                const Text(
                  'Aguardando internet para registrar o ajuste.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => unawaited(_cancelar(agendamento)),
          icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
          tooltip: 'Cancelar agendamento',
        ),
      ],
    ),
  );
}
