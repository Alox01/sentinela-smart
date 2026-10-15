import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/ciclo_secagem_entity.dart';
import '../../../models/evento_ciclo_entity.dart';

class EventosEstufadaCard extends StatelessWidget {
  final CicloSecagemEntity? cicloSelecionado;
  final List<EventoCicloEntity> eventos;
  final bool filtroAtivo;
  final TextStyle tituloSecaoStyle;

  const EventosEstufadaCard({
    super.key,
    required this.cicloSelecionado,
    required this.eventos,
    required this.filtroAtivo,
    required this.tituloSecaoStyle,
  });

  @override
  Widget build(BuildContext context) {
    const limiteEventos = 8;
    final eventosVisiveis = filtroAtivo
        ? eventos
        : eventos
              .skip(
                eventos.length > limiteEventos
                    ? eventos.length - limiteEventos
                    : 0,
              )
              .toList();

    return Container(
      padding: const EdgeInsets.all(12),
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
              'EVENTOS DA ESTUFADA',
              style: tituloSecaoStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          if (cicloSelecionado == null)
            const Text(
              'Selecione uma estufada para ver os eventos registrados.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else if (eventosVisiveis.isEmpty)
            const Text(
              'Nenhum evento importante registrado neste período.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else
            _ListaEventos(
              eventos: eventosVisiveis,
              comRolagem: filtroAtivo && eventosVisiveis.length > limiteEventos,
            ),
        ],
      ),
    );
  }
}

class _ListaEventos extends StatelessWidget {
  final List<EventoCicloEntity> eventos;
  final bool comRolagem;

  const _ListaEventos({required this.eventos, required this.comRolagem});

  @override
  Widget build(BuildContext context) {
    final lista = Column(children: _linhasComViradaDeDia(eventos));

    if (!comRolagem) return lista;

    return SizedBox(
      height: 260,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(child: lista),
      ),
    );
  }
}

/// Intercala uma faixa com a data a cada virada de dia.
///
/// A lista mostrava só a hora, e uma estufada que passa da meia-noite saía
/// assim: 19:02, 19:11, 08:00, 13:06. Parece fora de ordem — e a estufada de
/// 14/09 virou justamente uma dúvida de "por que os eventos estão embaralhados?",
/// quando a ordem estava certa e o que faltava era o dia.
///
/// A faixa só aparece quando a lista atravessa mais de um dia. Numa estufada que
/// começa e termina no mesmo dia ela seria repetição: a data já está no cabeçalho
/// da estufada selecionada.
List<Widget> _linhasComViradaDeDia(List<EventoCicloEntity> eventos) {
  final dias = eventos.map((e) => DateUtils.dateOnly(e.timestamp)).toSet();
  final atravessaDias = dias.length > 1;

  final linhas = <Widget>[];
  DateTime? diaAnterior;
  for (final evento in eventos) {
    final dia = DateUtils.dateOnly(evento.timestamp);
    if (atravessaDias && dia != diaAnterior) {
      linhas.add(_FaixaDoDia(dia: dia, primeira: diaAnterior == null));
      diaAnterior = dia;
    }
    linhas.add(_EventoLinha(evento: evento));
  }
  return linhas;
}

class _FaixaDoDia extends StatelessWidget {
  final DateTime dia;
  final bool primeira;

  const _FaixaDoDia({required this.dia, required this.primeira});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: primeira ? 0 : 6, bottom: 8),
      child: Row(
        children: [
          Text(
            DateFormat('dd/MM').format(dia),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Colors.white12, height: 1)),
        ],
      ),
    );
  }
}

class _EventoLinha extends StatelessWidget {
  final EventoCicloEntity evento;

  const _EventoLinha({required this.evento});

  @override
  Widget build(BuildContext context) {
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;
    final cor = switch (evento.severidade) {
      'critico' => Colors.redAccent,
      'alerta' => Colors.orangeAccent,
      // Anotado, nao julgado. E o que a umidade produz: ela nao aciona alarme em
      // lugar nenhum do sistema, entao nao pode sair aqui com a marca de quem
      // acionou. Verde tambem nao serviria - diria que esta tudo bem, e o valor
      // pode estar longe do ajuste.
      'registro' => Colors.white38,
      _ => Colors.greenAccent,
    };
    final horario = DateFormat('HH:mm').format(evento.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: telaEstreita ? 48 : 58,
            child: Text(
              horario,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          SizedBox(width: telaEstreita ? 6 : 8),
          Expanded(
            child: Text(
              _formatarDescricaoEvento(evento.descricao),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarDescricaoEvento(String descricao) {
    return descricao.replaceAllMapped(
      RegExp(r'([+-]?\d+)\.\d+(?=\s?°?F|%)'),
      (match) => match.group(1)!,
    );
  }
}
