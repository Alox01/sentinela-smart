import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/ciclo_secagem_entity.dart';
import '../../../services/isar_service.dart';
import '../services/relatorio_estufada_repository.dart';

/// Limpeza em lote de estufadas (util na fase de teste): lista os ciclos de uma
/// estufa com selecao multipla e apaga os escolhidos (ciclo + eventos +
/// leituras do periodo).
class GerenciarEstufadasScreen extends StatefulWidget {
  final String nomeEstufa;
  final String ipEstufa;

  const GerenciarEstufadasScreen({
    super.key,
    required this.nomeEstufa,
    required this.ipEstufa,
  });

  @override
  State<GerenciarEstufadasScreen> createState() =>
      _GerenciarEstufadasScreenState();
}

class _GerenciarEstufadasScreenState extends State<GerenciarEstufadasScreen> {
  final RelatorioEstufadaRepository _repo = RelatorioEstufadaRepository(
    IsarService.instance,
  );

  List<CicloSecagemEntity> _ciclos = [];
  final Map<int, int> _posicaoPorCiclo = {};
  final Set<int> _selecionados = {};
  bool _carregando = true;
  bool _apagando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final ciclos = await _repo.listarCiclosPorIp(widget.ipEstufa);
    if (!mounted) return;

    // Mesma regra da tela de relatorio: posicao por ordem de inicio.
    final ordenados = [...ciclos]..sort((a, b) => a.inicio.compareTo(b.inicio));
    _posicaoPorCiclo.clear();
    for (var i = 0; i < ordenados.length; i++) {
      _posicaoPorCiclo[ordenados[i].id] = i + 1;
    }

    setState(() {
      _ciclos = ciclos;
      _selecionados.removeWhere((id) => !ciclos.any((c) => c.id == id));
      _carregando = false;
    });
  }

  String _tituloCiclo(CicloSecagemEntity ciclo) {
    final pos = _posicaoPorCiclo[ciclo.id] ?? _ciclos.length;
    return 'Estufada $pos';
  }

  String _periodoCiclo(CicloSecagemEntity ciclo) {
    final inicio = DateFormat('dd/MM HH:mm').format(ciclo.inicio);
    final fim = ciclo.fim == null
        ? 'em andamento'
        : DateFormat('dd/MM HH:mm').format(ciclo.fim!);
    return '$inicio - $fim';
  }

  Future<void> _apagarSelecionadas() async {
    if (_selecionados.isEmpty) return;
    final quantidade = _selecionados.length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252830),
        title: const Text(
          'Apagar estufadas?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Você vai apagar $quantidade estufada(s). Isto remove o relatório, os '
          'eventos e as leituras de cada ciclo. Não dá para desfazer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _apagando = true);
    await _repo.apagarCiclos(_selecionados.toList());
    if (!mounted) return;
    _selecionados.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$quantidade estufada(s) apagada(s).')),
    );
    setState(() => _apagando = false);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17191D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apagar estufadas', style: TextStyle(fontSize: 16)),
            Text(
              widget.nomeEstufa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _ciclos.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma estufada registrada para esta estufa.',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _ciclos.length,
              itemBuilder: (context, index) {
                final ciclo = _ciclos[index];
                final marcada = _selecionados.contains(ciclo.id);
                return CheckboxListTile(
                  value: marcada,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    _tituloCiclo(ciclo),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _periodoCiclo(ciclo),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onChanged: _apagando
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _selecionados.add(ciclo.id);
                            } else {
                              _selecionados.remove(ciclo.id);
                            }
                          });
                        },
                );
              },
            ),
      bottomNavigationBar: _ciclos.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: (_selecionados.isEmpty || _apagando)
                      ? null
                      : _apagarSelecionadas,
                  // Acao principal E destrutiva: fundo vermelho.
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _apagando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(
                    _selecionados.isEmpty
                        ? 'Selecione estufadas para apagar'
                        : 'Apagar ${_selecionados.length} selecionada(s)',
                  ),
                ),
              ),
            ),
    );
  }
}
