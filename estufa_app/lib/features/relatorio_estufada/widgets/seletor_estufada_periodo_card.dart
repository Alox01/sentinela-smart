import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/ciclo_secagem_entity.dart';

class SeletorEstufadaPeriodoCard extends StatelessWidget {
  final List<CicloSecagemEntity> ciclos;
  final int? cicloSelecionadoId;
  final DateTime? diaSelecionado;
  final TextStyle tituloSecaoStyle;
  final ValueChanged<int> onCicloChanged;
  final VoidCallback? onSelecionarDia;
  final VoidCallback? onDiaAnterior;
  final VoidCallback? onProximoDia;
  final String Function(CicloSecagemEntity ciclo) rotuloCiclo;

  const SeletorEstufadaPeriodoCard({
    super.key,
    required this.ciclos,
    required this.cicloSelecionadoId,
    required this.diaSelecionado,
    required this.tituloSecaoStyle,
    required this.onCicloChanged,
    required this.onSelecionarDia,
    required this.onDiaAnterior,
    required this.onProximoDia,
    required this.rotuloCiclo,
  });

  @override
  Widget build(BuildContext context) {
    final valorAtual =
        cicloSelecionadoId != null &&
            ciclos.any((c) => c.id == cicloSelecionadoId)
        ? cicloSelecionadoId
        : null;
    final cicloSelecionado = valorAtual == null
        ? null
        : ciclos.firstWhere((c) => c.id == valorAtual);
    final textoSelecionado = cicloSelecionado == null
        ? 'Nenhuma estufada selecionada'
        : 'Selecionada: Estufada ${rotuloCiclo(cicloSelecionado)}';
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;
    // Destaque do seletor no lilas do tema (mesmo dos botoes), em vez do laranja.
    final destaque = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              'ESCOLHA A ESTUFADA PARA O RELATÓRIO',
              style: tituloSecaoStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: destaque.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: destaque.withValues(alpha: 0.45)),
              ),
              child: _SeletorEstufada(
                ciclos: ciclos,
                valorAtual: valorAtual,
                telaEstreita: telaEstreita,
                rotuloCiclo: rotuloCiclo,
                onCicloChanged: onCicloChanged,
              ),
            ),
          ),
          const SizedBox(height: 8),
          RotuloEstufada(
            textoSelecionado,
            estilo: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _FiltroPeriodo(
            diaSelecionado: diaSelecionado,
            telaEstreita: telaEstreita,
            tituloSecaoStyle: tituloSecaoStyle,
            onSelecionarDia: onSelecionarDia,
            onDiaAnterior: onDiaAnterior,
            onProximoDia: onProximoDia,
          ),
        ],
      ),
    );
  }
}

class _SeletorEstufada extends StatelessWidget {
  final List<CicloSecagemEntity> ciclos;
  final int? valorAtual;
  final bool telaEstreita;
  final String Function(CicloSecagemEntity ciclo) rotuloCiclo;
  final ValueChanged<int> onCicloChanged;

  const _SeletorEstufada({
    required this.ciclos,
    required this.valorAtual,
    required this.telaEstreita,
    required this.rotuloCiclo,
    required this.onCicloChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (telaEstreita) {
      return _SeletorEstufadaExpansivel(
        ciclos: ciclos,
        valorAtual: valorAtual,
        rotuloCiclo: rotuloCiclo,
        onCicloChanged: onCicloChanged,
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: valorAtual,
        dropdownColor: const Color(0xFF252830),
        iconEnabledColor: Colors.white70,
        isExpanded: true,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        items: [
          for (final ciclo in ciclos)
            DropdownMenuItem<int?>(
              value: ciclo.id,
              child: _OpcaoEstufada(rotulo: rotuloCiclo(ciclo)),
            ),
        ],
        onChanged: (value) {
          if (value != null) onCicloChanged(value);
        },
      ),
    );
  }
}

class _SeletorEstufadaExpansivel extends StatefulWidget {
  final List<CicloSecagemEntity> ciclos;
  final int? valorAtual;
  final String Function(CicloSecagemEntity ciclo) rotuloCiclo;
  final ValueChanged<int> onCicloChanged;

  const _SeletorEstufadaExpansivel({
    required this.ciclos,
    required this.valorAtual,
    required this.rotuloCiclo,
    required this.onCicloChanged,
  });

  @override
  State<_SeletorEstufadaExpansivel> createState() =>
      _SeletorEstufadaExpansivelState();
}

class _SeletorEstufadaExpansivelState
    extends State<_SeletorEstufadaExpansivel> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final cicloSelecionado = widget.valorAtual == null
        ? null
        : widget.ciclos.where((c) => c.id == widget.valorAtual).firstOrNull;
    final rotulo = cicloSelecionado == null
        ? 'Selecione uma estufada'
        : widget.rotuloCiclo(cicloSelecionado);

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _expandido = !_expandido),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: _OpcaoEstufada(rotulo: rotulo)),
                Icon(
                  _expandido ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final ciclo in widget.ciclos)
                      _EstufadaExpansivelItem(
                        selecionada: ciclo.id == widget.valorAtual,
                        rotulo: widget.rotuloCiclo(ciclo),
                        onTap: () {
                          widget.onCicloChanged(ciclo.id);
                          setState(() => _expandido = false);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          crossFadeState: _expandido
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 160),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

class _EstufadaExpansivelItem extends StatelessWidget {
  final bool selecionada;
  final String rotulo;
  final VoidCallback onTap;

  const _EstufadaExpansivelItem({
    required this.selecionada,
    required this.rotulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final destaque = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selecionada
                ? destaque.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selecionada
                  ? destaque.withValues(alpha: 0.5)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Expanded(child: _OpcaoEstufada(rotulo: rotulo)),
              if (selecionada) Icon(Icons.check, color: destaque, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcaoEstufada extends StatelessWidget {
  final String rotulo;

  const _OpcaoEstufada({required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return RotuloEstufada('Estufada $rotulo');
  }
}

/// Rótulo de estufada que cabe inteiro, em até duas linhas.
///
/// O rótulo tem nome, data, hora e "em andamento" — quase sempre mais do que
/// cabe numa linha de celular, e o que sobrava era justamente o fim: onde está a
/// informação que distingue uma estufada da outra. Cortado, o produtor escolhia
/// entre duas linhas iguais.
///
/// Duas linhas, e não o balão de toque que a barra do monitoramento usa: lá a
/// altura é fixa e não há para onde crescer, e aqui há. Além disso os dois
/// lugares onde isto aparece JÁ respondem ao toque — um abre a lista, o outro
/// seleciona a estufada —, e um balão brigaria com o gesto que já existe.
class RotuloEstufada extends StatelessWidget {
  final String texto;
  final TextStyle? estilo;

  const RotuloEstufada(this.texto, {super.key, this.estilo});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: estilo,
      maxLines: 2,
      // A reticência continua como rede de segurança: nome de estufa longo com
      // data ainda pode passar de duas linhas, e transbordar quebra o layout.
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FiltroPeriodo extends StatelessWidget {
  final DateTime? diaSelecionado;
  final bool telaEstreita;
  final TextStyle tituloSecaoStyle;
  final VoidCallback? onSelecionarDia;
  final VoidCallback? onDiaAnterior;
  final VoidCallback? onProximoDia;

  const _FiltroPeriodo({
    required this.diaSelecionado,
    required this.telaEstreita,
    required this.tituloSecaoStyle,
    required this.onSelecionarDia,
    required this.onDiaAnterior,
    required this.onProximoDia,
  });

  @override
  Widget build(BuildContext context) {
    final diaTexto = diaSelecionado == null
        ? 'Selecione um dia'
        : DateFormat('dd/MM/yyyy').format(diaSelecionado!);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              'DIA EXIBIDO',
              style: tituloSecaoStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(
            width: double.infinity,
            child: Text(
              'O PDF e o CSV sempre incluem a estufada completa.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: onDiaAnterior,
                icon: const Icon(Icons.chevron_left),
                color: Colors.white70,
                tooltip: 'Dia anterior',
              ),
              SizedBox(width: telaEstreita ? 6 : 10),
              Expanded(
                child: _BotaoFiltroPeriodo(
                  texto: diaTexto,
                  icone: Icons.calendar_today,
                  telaEstreita: telaEstreita,
                  onPressed: onSelecionarDia,
                ),
              ),
              SizedBox(width: telaEstreita ? 6 : 10),
              IconButton(
                onPressed: onProximoDia,
                icon: const Icon(Icons.chevron_right),
                color: Colors.white70,
                tooltip: 'Próximo dia',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotaoFiltroPeriodo extends StatelessWidget {
  final String texto;
  final IconData icone;
  final bool telaEstreita;
  final VoidCallback? onPressed;

  const _BotaoFiltroPeriodo({
    required this.texto,
    required this.icone,
    required this.telaEstreita,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: telaEstreita ? 14 : 16),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: telaEstreita ? 6 : 16,
          vertical: telaEstreita ? 10 : 12,
        ),
      ),
      label: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(fontSize: telaEstreita ? 11 : null),
      ),
    );
  }
}
