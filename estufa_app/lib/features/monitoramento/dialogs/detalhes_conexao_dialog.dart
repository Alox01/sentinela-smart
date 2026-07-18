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
  required String? baseUrlAtiva,
  required String localBaseUrl,
  required String? cloudBaseUrl,
  required bool temTokenConfigurado,
  required int totalPendencias,
  required List<PendingSyncCommandEntity> pendencias,
  required Future<List<ApiConnectionProbe>> probesFuture,
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
                        _LinhaDetalhe('Ativo', baseUrlAtiva ?? '-'),
                        _LinhaDetalhe('Local', localBaseUrl),
                        _LinhaDetalhe(
                          'Nuvem',
                          cloudBaseUrl ?? 'N\u00E3o configurada',
                        ),
                        _LinhaDetalhe(
                          'Chave',
                          temTokenConfigurado
                              ? 'Configurada'
                              : 'N\u00E3o configurada',
                        ),
                        _LinhaDetalhe('Pend\u00EAncias', '$totalPendencias'),
                        const SizedBox(height: 14),
                        const Text(
                          'TESTE DE ALCANCE (SERVIDORES)',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Diz se o celular alcança cada endereço — '
                          'não se o aparelho está reportando.',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<ApiConnectionProbe>>(
                          future: probesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Verificando conex\u00E3o...',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final probes =
                                snapshot.data ?? <ApiConnectionProbe>[];
                            if (probes.isEmpty) {
                              return const Text(
                                'N\u00E3o foi poss\u00EDvel verificar agora.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              );
                            }

                            return Column(
                              children: [
                                for (final probe in probes)
                                  _ProbeConexao(probe),
                              ],
                            );
                          },
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
