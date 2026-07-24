import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/preferencias_notificacao.dart';
import '../services/preferencias_notificacao_service.dart';
import '../services/push_notification_service.dart';

/// O buzzer atual de UM aparelho e a funcao que muda esse estado (envia o
/// comando). So existe quando a tela e aberta pelo monitoramento de uma estufa.
class ControleAlarmeAparelho {
  final bool buzzerAtivo;
  // Envia o comando ao aparelho; devolve se conseguiu.
  final Future<bool> Function(bool ativo) definir;
  const ControleAlarmeAparelho({
    required this.buzzerAtivo,
    required this.definir,
  });
}

/// Preferencias de notificacao (o que avisar / tocar) — globais, valem para
/// todas as estufas. Quando aberta pelo monitoramento de uma estufa recebe um
/// [controleAparelho] e mostra tambem o alarme fisico daquele aparelho; pelo
/// acesso global (home) esse controle e nulo e a secao nao aparece.
class NotificacoesScreen extends StatefulWidget {
  final ControleAlarmeAparelho? controleAparelho;

  const NotificacoesScreen({super.key, this.controleAparelho});

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
  late bool _buzzerAtivo;

  @override
  void initState() {
    super.initState();
    _buzzerAtivo = widget.controleAparelho?.buzzerAtivo ?? true;
    if (_ehAndroid) unawaited(_conferirNaoPerturbe());
  }

  Future<void> _mudarBuzzer(bool ativo) async {
    final controle = widget.controleAparelho;
    if (controle == null) return;
    // So confirma ao DESLIGAR: religar nao tem risco.
    if (!ativo) {
      final ok = await _confirmarDesligarBuzzer();
      if (ok != true) return;
    }
    final enviado = await controle.definir(ativo);
    if (!mounted) return;
    if (enviado) {
      setState(() => _buzzerAtivo = ativo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar ao aparelho.')),
      );
    }
  }

  Future<bool?> _confirmarDesligarBuzzer() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Desligar o alarme do aparelho?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'O aparelho vai parar de tocar a sirene de temperatura na estufa. '
          'O aviso de incêndio continua tocando sempre, e as notificações no '
          'celular também. Só a sirene de temperatura fica muda.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Desligar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
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
          // Rotulos curtos de proposito: o AlertDialog empilha os botoes quando
          // eles nao cabem lado a lado. "Manter ligado" + "Desligar mesmo
          // assim" estouravam a linha e quebravam o padrao das outras telas.
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Desligar',
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
        border: Border.all(color: Colors.white10),
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
                color: Colors.white70,
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
          // Botao sempre presente: quando ainda nao liberado, ele libera;
          // quando ja liberado, leva o produtor as configuracoes do sistema
          // para conferir ou revogar. Sem isto, o card virava so texto e o
          // toque nao fazia nada.
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _pedirNaoPerturbe,
              child: Text(
                liberado
                    ? 'Ver nas configurações'
                    : 'Liberar nas configurações',
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Isso não vence o modo silencioso do aparelho.',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Alarme fisico daquele aparelho: so aparece quando ha controleAparelho (ou
  // seja, aberto pelo monitoramento de uma estufa). Fogo nunca e afetado.
  Widget _cartaoAlarmeAparelho() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign_outlined, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alarme do aparelho',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'A sirene de temperatura na própria estufa. O alarme de incêndio '
            'continua tocando sempre, independente disto.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Tocar na estufa',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            value: _buzzerAtivo,
            onChanged: _mudarBuzzer,
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
                if (widget.controleAparelho != null) _cartaoAlarmeAparelho(),
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
