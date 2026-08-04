import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../models/pending_sync_command_entity.dart';
import '../../../services/api_service.dart';

Future<void> mostrarDetalhesConexaoDialog({
  required BuildContext context,
  required String modoConexao,
  // Estado do aparelho (esta reportando ou nao), separado do alcance dos
  // servidores: a nuvem pode estar de pe e o aparelho, mudo.
  required String estadoAparelho,
  // Versao do firmware relatada pelo aparelho. Fica visivel, e nao nos detalhes
  // tecnicos, porque a pergunta "qual versao esta naquele ESP?" so aparece
  // quando ja se esta em campo - e ate aqui a unica resposta era ir ate la com
  // um terminal. Nulo quando ainda nao chegou leitura nenhuma.
  required String? versaoFirmware,
  // Qual aparelho esta estufa le na nuvem. Sem isso nao havia como responder
  // "de quem sao estes numeros?" - e ja houve uma estufa exibindo a leitura de
  // outra, por um endereco reaproveitado.
  required String? idHardware,
  required String? baseUrlAtiva,
  required String localBaseUrl,
  required String? cloudBaseUrl,
  // Este celular esta inscrito para receber avisos deste aparelho? `null` = a
  // conferencia ainda nao terminou. Estava no menu da estufa e saiu de la: o
  // produtor nao sabe o que e uma inscricao de push, nao pode agir sobre ela, e
  // ler "ativos" so levantava duvida. Aqui e diagnostico, e quem abre isto esta
  // procurando defeito - inclusive o defeito de nunca ter chegado um aviso.
  required bool? vigiadaPorPush,
  required int totalPendencias,
  required List<PendingSyncCommandEntity> pendencias,
  // O ultimo teste ja feito nesta estufa (nulo na primeira vez) e como refazer.
  // Reabrir o dialogo mostra o que ja se sabe em vez de sondar tudo de novo.
  required ResultadoAlcance? alcanceConhecido,
  required Future<List<ApiConnectionProbe>> Function() testarAlcance,
  required bool sincronizandoPendencias,
  required VoidCallback onLimparFila,
  required VoidCallback onSincronizar,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final tamanho = MediaQuery.sizeOf(context);
      final telaEstreita = tamanho.width < 430;

      return Dialog(
        backgroundColor: const Color(0xFF1E2129),
        insetPadding: EdgeInsets.symmetric(
          horizontal: telaEstreita ? 18 : 32,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: tamanho.height * 0.82,
          ),
          child: Padding(
            padding: EdgeInsets.all(telaEstreita ? 20 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conex\u00E3o da estufa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LinhaDetalhe('Modo atual', modoConexao),
                        _LinhaDetalhe('Aparelho', estadoAparelho),
                        _LinhaDetalhe(
                          'Firmware',
                          versaoFirmware ?? 'Desconhecida',
                        ),
                        // Nao ha linha de "Chave". Ela dizia "Configurada"
                        // ou "Nao configurada" para um segredo que o produtor
                        // nunca viu, nao escolheu e nao tem como configurar —
                        // e no simulador dizia "Nao configurada" o tempo todo,
                        // que parece defeito e nao e. Quem precisa saber se a
                        // chave chegou olha o aparelho no modo de configuracao.
                        _LinhaDetalhe('Pend\u00EAncias', '$totalPendencias'),
                        const SizedBox(height: 14),
                        const Text(
                          'TESTE DE ALCANCE',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _TesteDeAlcance(
                          alcanceConhecido: alcanceConhecido,
                          testar: testarAlcance,
                        ),
                        // Enderecos ficam fechados: para o produtor sao ruido -
                        // ele quer saber se esta funcionando, nao por onde. Quem
                        // diagnostica em campo abre e ve tudo. Nada aqui da
                        // acesso a nada (a chave nunca e mostrada), mas nao ha
                        // motivo para o nome do aparelho viajar em cada print.
                        _DetalhesTecnicos(
                          vigiadaPorPush: vigiadaPorPush,
                          idHardware: idHardware,
                          baseUrlAtiva: baseUrlAtiva,
                          localBaseUrl: localBaseUrl,
                          cloudBaseUrl: cloudBaseUrl,
                        ),
                        if (pendencias.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            '\u00DALTIMAS PEND\u00CANCIAS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final pendencia in pendencias)
                            _PendenciaLinha(pendencia: pendencia),
                          if (totalPendencias > pendencias.length)
                            Text(
                              'Mais ${totalPendencias - pendencias.length} comando(s) aguardando sincroniza\u00E7\u00E3o.',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 6),
                          const Text(
                            'Esses comandos ser\u00E3o enviados automaticamente quando a estufa voltar a conectar.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fechar'),
                      ),
                      TextButton.icon(
                        onPressed: totalPendencias <= 0
                            ? null
                            : () {
                                Navigator.pop(context);
                                onLimparFila();
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Limpar fila'),
                      ),
                      FilledButton.icon(
                        onPressed: sincronizandoPendencias
                            ? null
                            : () {
                                Navigator.pop(context);
                                onSincronizar();
                              },
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Sincronizar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Enderecos de rede, fechados por padrao. Sao a ferramenta de quem investiga
/// "por que nao conecta", nao informacao de rotina para quem cuida da estufa.
class _DetalhesTecnicos extends StatefulWidget {
  final String? idHardware;
  final bool? vigiadaPorPush;
  final String? baseUrlAtiva;
  final String localBaseUrl;
  final String? cloudBaseUrl;

  const _DetalhesTecnicos({
    required this.idHardware,
    required this.baseUrlAtiva,
    required this.localBaseUrl,
    required this.cloudBaseUrl,
    required this.vigiadaPorPush,
  });

  @override
  State<_DetalhesTecnicos> createState() => _DetalhesTecnicosState();
}

class _DetalhesTecnicosState extends State<_DetalhesTecnicos> {
  bool _aberto = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        InkWell(
          onTap: () => setState(() => _aberto = !_aberto),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _aberto ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Detalhes técnicos',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (_aberto) ...[
          const SizedBox(height: 4),
          _LinhaDetalhe('Aparelho (id)', widget.idHardware ?? 'Não identificado'),
          _LinhaDetalhe('Ativo', widget.baseUrlAtiva ?? '-'),
          _LinhaDetalhe('Local', widget.localBaseUrl),
          _LinhaDetalhe('Nuvem', widget.cloudBaseUrl ?? 'Não configurada'),
          _LinhaDetalhe(
            'Avisos push',
            switch (widget.vigiadaPorPush) {
              true => 'Este celular inscrito',
              false => 'NÃO inscrito',
              null => 'Conferindo',
            },
          ),
        ],
      ],
    );
  }
}

class _LinhaDetalhe extends StatelessWidget {
  final String label;
  final String valor;

  const _LinhaDetalhe(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    final telaEstreita = MediaQuery.sizeOf(context).width < 430;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: telaEstreita ? 86 : 112,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Secao do teste de alcance: mostra o ultimo resultado conhecido de imediato e
/// deixa refazer sob demanda. Sondar a nuvem pode levar mais de 10 s, entao
/// refazer tudo a cada abertura do dialogo so servia para fazer esperar.
class _TesteDeAlcance extends StatefulWidget {
  final ResultadoAlcance? alcanceConhecido;
  final Future<List<ApiConnectionProbe>> Function() testar;

  const _TesteDeAlcance({required this.alcanceConhecido, required this.testar});

  @override
  State<_TesteDeAlcance> createState() => _TesteDeAlcanceState();
}

class _TesteDeAlcanceState extends State<_TesteDeAlcance> {
  late List<ApiConnectionProbe> _probes;
  late DateTime? _quando;
  bool _testando = false;

  @override
  void initState() {
    super.initState();
    _probes = widget.alcanceConhecido?.probes ?? const [];
    _quando = widget.alcanceConhecido?.quando;
    // Sem nada conhecido, testa sozinho: e a primeira vez nesta estufa.
    if (_probes.isEmpty) _testar();
  }

  Future<void> _testar() async {
    setState(() => _testando = true);
    final probes = await widget.testar();
    if (!mounted) return;
    setState(() {
      _probes = probes;
      _quando = DateTime.now();
      _testando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_testando && _probes.isEmpty) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Verificando conexão...',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    if (_probes.isEmpty) {
      return const Text(
        'Não foi possível verificar agora.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final probe in _probes) _ProbeConexao(probe),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                _quando == null ? '' : 'Verificado ${_desde(_quando!)}.',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: _testando ? null : _testar,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _testando ? 'Testando...' : 'Testar de novo',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _desde(DateTime quando) {
    final segundos = DateTime.now().difference(quando).inSeconds;
    if (segundos < 60) return 'agora há pouco';
    final minutos = segundos ~/ 60;
    if (minutos < 60) return 'há $minutos min';
    return 'há ${minutos ~/ 60}h';
  }
}

class _ProbeConexao extends StatelessWidget {
  final ApiConnectionProbe probe;

  const _ProbeConexao(this.probe);

  @override
  Widget build(BuildContext context) {
    final cor = probe.online ? Colors.greenAccent : Colors.redAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            probe.online ? Icons.check_circle_outline : Icons.error_outline,
            color: cor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${probe.nome}: ${probe.online ? 'online' : 'offline'}',
              style: TextStyle(color: cor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendenciaLinha extends StatelessWidget {
  final PendingSyncCommandEntity pendencia;

  const _PendenciaLinha({required this.pendencia});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Colors.amberAccent,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatarPendencia(pendencia.payloadJson),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarPendencia(String payloadJson) {
    try {
      final payload = jsonDecode(payloadJson);
      if (payload is! Map<String, dynamic>) {
        return 'Comando aguardando sincroniza\u00E7\u00E3o';
      }

      if (payload.containsKey('temperaturaMeta')) {
        final valor = double.tryParse(payload['temperaturaMeta'].toString());
        return valor == null
            ? 'Alterar ajuste de temperatura'
            : 'Alterar ajuste de temperatura para ${valor.toStringAsFixed(0)}\u00B0F';
      }

      if (payload.containsKey('umidadeMeta')) {
        final valor = double.tryParse(payload['umidadeMeta'].toString());
        return valor == null
            ? 'Alterar ajuste de umidade'
            : 'Alterar ajuste de umidade para ${valor.toStringAsFixed(0)}%';
      }

      if (payload.containsKey('modoSilencioso') ||
          payload['comando'] == 'silenciar') {
        return payload['modoSilencioso'] == true ||
                payload['comando'] == 'silenciar'
            ? 'Silenciar alarme'
            : 'Reativar alarme';
      }
    } catch (_) {
      return 'Comando aguardando sincroniza\u00E7\u00E3o';
    }

    return 'Comando aguardando sincroniza\u00E7\u00E3o';
  }
}
