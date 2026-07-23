import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/preferencias_notificacao.dart';
import '../services/preferencias_notificacao_service.dart';
import '../services/push_notification_service.dart';

/// Preferencias de notificacao, globais. Cada evento tem dois interruptores:
/// mostrar a mensagem e fazer o celular tocar/vibrar.
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  final _servico = PreferenciasNotificacaoService.instance;

  // O "Nao perturbe" so existe no Android; nas outras plataformas o cartao nem
  // aparece, em vez de mostrar um botao que nao faz nada.
  bool get _ehAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool? _furaNaoPerturbe;

  @override
  void initState() {
    super.initState();
    if (_ehAndroid) unawaited(_conferirNaoPerturbe());
  }

  Future<void> _conferirNaoPerturbe() async {
    final pode = await PushNotificationService.instance.podeFurarNaoPerturbe;
    if (mounted) setState(() => _furaNaoPerturbe = pode);
  }

  Future<void> _pedirNaoPerturbe() async {
    await PushNotificationService.instance.solicitarPermissaoNaoPerturbe();
    // Reconsulta em vez de confiar no retorno: o produtor pode ter voltado da
    // tela do sistema sem concluir.
    await _conferirNaoPerturbe();
  }

  Future<void> _mudar(
    EventoNotificacao evento,
    OpcaoEvento nova,
    bool desligandoNotificarIncendio,
  ) async {
    if (desligandoNotificarIncendio) {
      final confirma = await _confirmarDesligarIncendio();
      if (confirma != true) return;
    }
    await _servico.atualizar(
      _servico.preferencias.comEvento(evento, nova),
    );
  }

  Future<bool?> _confirmarDesligarIncendio() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Desligar aviso de incêndio?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Você não será avisado no celular sobre princípios de incêndio. '
          'A sirene do próprio aparelho continua funcionando, mas o alerta '
          'remoto é importante — principalmente à noite. Tem certeza?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Manter ligado'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Desligar mesmo assim',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoNaoPerturbe() {
    final liberado = _furaNaoPerturbe == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: liberado
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.amberAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                liberado
                    ? Icons.notifications_active_rounded
                    : Icons.do_not_disturb_on_rounded,
                color: liberado ? Colors.greenAccent : Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Tocar no "Não perturbe"',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            liberado
                ? 'Liberado. O aviso de incêndio toca como alarme mesmo com o '
                      'celular no "Não perturbe".'
                : 'Sem isso, o aviso de incêndio fica mudo enquanto o celular '
                      'estiver no "Não perturbe" — justamente de madrugada.',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          if (!liberado) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _pedirNaoPerturbe,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: BorderSide(
                    color: Colors.amberAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text('Liberar nas configurações'),
              ),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Isso não vence o modo silencioso do aparelho.',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191D),
        foregroundColor: Colors.white,
        title: const Text('Notificações'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _servico,
          builder: (context, _) {
            final prefs = _servico.preferencias;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const Text(
                  'Escolha o que avisar e o que faz o celular tocar ou vibrar. '
                  'Vale para todas as estufas.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final evento in EventoNotificacao.values)
                  _CartaoEvento(
                    evento: evento,
                    opcao: prefs.opcao(evento),
                    aoMudar: (nova, desligandoIncendio) =>
                        _mudar(evento, nova, desligandoIncendio),
                  ),
                if (_ehAndroid) _cartaoNaoPerturbe(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'As notificações são do app, não do alarme do aparelho.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartaoEvento extends StatelessWidget {
  final EventoNotificacao evento;
  final OpcaoEvento opcao;
  // (nova opcao, estaDesligandoNotificarIncendio)
  final void Function(OpcaoEvento, bool) aoMudar;

  const _CartaoEvento({
    required this.evento,
    required this.opcao,
    required this.aoMudar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  evento.titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            evento.descricao,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Notificar',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            value: opcao.notificar,
            onChanged: (v) {
              // Desligar "notificar" tambem tira o tocar/vibrar: sem mensagem
              // nao ha o que tocar.
              final nova = v
                  ? opcao.copyWith(notificar: true)
                  : const OpcaoEvento(notificar: false, tocarVibrar: false);
              aoMudar(nova, evento.critico && !v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Tocar / vibrar',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            // So faz sentido tocar se for notificar.
            value: opcao.tocarVibrar && opcao.notificar,
            onChanged: opcao.notificar
                ? (v) => aoMudar(opcao.copyWith(tocarVibrar: v), false)
                : null,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
