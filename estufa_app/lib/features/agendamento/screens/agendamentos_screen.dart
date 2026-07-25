import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamento_ajuste.dart';
import '../services/agendamento_service.dart';

/// Agenda um ajuste para mais tarde e lista o que ja esta marcado.
///
/// O caso que originou a tela: o produtor quer o alvo em 120 °F daqui duas
/// horas, e nessa hora nao vai estar por perto.
class AgendamentosScreen extends StatefulWidget {
  final int idEstufa;
  final String nomeEstufa;
  final String? idHardware;
  final String? tokenAcesso;

  /// Alvos vigentes, so para mostrar de onde o valor relativo vai partir.
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

  bool _relativo = false;
  double _tempAbsoluta = 120;
  double _tempDelta = 10;
  bool _mexerUmidade = false;
  double _umidAbsoluta = 40;
  double _umidDelta = -10;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_servico.carregar());
    _tempAbsoluta = widget.temperaturaAtual > 0
        ? widget.temperaturaAtual
        : _tempAbsoluta;
    _umidAbsoluta = widget.umidadeAtual > 0
        ? widget.umidadeAtual
        : _umidAbsoluta;
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
      temperaturaMeta: _relativo ? null : _tempAbsoluta,
      temperaturaDelta: _relativo ? _tempDelta : null,
      umidadeMeta: _mexerUmidade && !_relativo ? _umidAbsoluta : null,
      umidadeDelta: _mexerUmidade && _relativo ? _umidDelta : null,
    );
    if (!mounted) return;
    setState(() => _salvando = false);

    // Honesto sobre o alcance: sem registro na nuvem o aviso sai na hora, mas o
    // alvo nao muda sozinho com o app fechado.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          agendamento.registradoNaNuvem
              ? 'Agendado para ${_formato.format(agendamento.quando)}.'
              : 'Aviso agendado, mas o alvo não vai mudar sozinho — '
                    'não foi possível registrar na nuvem.',
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
                Text(
                  'O celular avisa na hora marcada, mesmo sem internet. '
                  'O alvo muda sozinho pela nuvem — o aquecimento em si continua '
                  'na sua mão, na fornalha.',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
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
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Deixar em')),
            ButtonSegment(value: true, label: Text('Variar')),
          ],
          selected: {_relativo},
          onSelectionChanged: (s) => setState(() => _relativo = s.first),
        ),
        const SizedBox(height: 6),
        Text(
          _relativo
              // O relativo e resolvido na hora de aplicar: se o produtor mexer no
              // alvo antes disso, a variacao parte do valor novo.
              ? 'A variação parte do alvo que estiver valendo na hora.'
              : 'O alvo vai ficar exatamente neste valor.',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _seletorNumero(
          rotulo: 'Temperatura (°F)',
          valor: _relativo ? _tempDelta : _tempAbsoluta,
          minimo: _relativo ? -50 : 60,
          maximo: _relativo ? 50 : 200,
          comSinal: _relativo,
          aoMudar: (v) => setState(() {
            if (_relativo) {
              _tempDelta = v;
            } else {
              _tempAbsoluta = v;
            }
          }),
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
            valor: _relativo ? _umidDelta : _umidAbsoluta,
            minimo: _relativo ? -100 : 0,
            maximo: _relativo ? 100 : 100,
            comSinal: _relativo,
            aoMudar: (v) => setState(() {
              if (_relativo) {
                _umidDelta = v;
              } else {
                _umidAbsoluta = v;
              }
            }),
          ),
      ],
    ),
  );

  Widget _seletorNumero({
    required String rotulo,
    required double valor,
    required double minimo,
    required double maximo,
    required bool comSinal,
    required ValueChanged<double> aoMudar,
  }) {
    final texto = comSinal && valor >= 0
        ? '+${valor.toStringAsFixed(0)}'
        : valor.toStringAsFixed(0);
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
          IconButton(
            onPressed: valor <= minimo ? null : () => aoMudar(valor - 1),
            icon: const Icon(Icons.remove),
            color: Colors.white70,
          ),
          SizedBox(
            width: 52,
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: valor >= maximo ? null : () => aoMudar(valor + 1),
            icon: const Icon(Icons.add),
            color: Colors.white70,
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
                  'Só o aviso — o alvo não muda sozinho.',
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
