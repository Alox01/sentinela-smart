import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/preferencias_notificacao.dart';
import '../services/controle_buzzer_global.dart';
import '../services/preferencias_notificacao_service.dart';
import '../services/push_notification_service.dart';

/// Preferencias de notificacao (o que avisar / tocar) — globais, valem para
/// todas as estufas. O alarme fisico (buzzer de temperatura) tambem e global:
/// um so interruptor para todos os aparelhos. Para desligar so um, o produtor
/// segura o botao do buzzer no proprio aparelho.
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  final _servico = PreferenciasNotificacaoService.instance;
  final _buzzer = ControleBuzzerGlobal.instance;

  // O "Nao perturbe" so existe no Android; nas outras plataformas o cartao nem
  // aparece, em vez de mostrar um botao que nao faz nada.
  bool get _ehAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool? _furaNaoPerturbe;

  @override
  void initState() {
    super.initState();
    unawaited(_buzzer.carregar());
    if (_ehAndroid) unawaited(_conferirNaoPerturbe());
  }

  Future<void> _mudarBuzzer(bool ativo) async {
    // So confirma ao DESLIGAR: religar nao tem risco.
    if (!ativo) {
      final ok = await _confirmarDesligarBuzzer();
      if (ok != true) return;
    }
    // O proprio servico ja move o interruptor na hora (notifyListeners) e envia
    // em segundo plano. A intencao fica salva mesmo se nenhuma estufa estiver
    // alcancavel: as offline recebem ao reconectar.
    final alcancou = await _buzzer.definir(ativo);
    if (!mounted || alcancou || ativo) return;
    // Desligou e nenhuma respondeu agora: avisa que vale quando reconectarem
    // (sem desfazer — a intencao global continua valendo).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aplicado. As estufas offline recebem ao reconectar.'),
      ),
    );
  }

  Future<bool?> _confirmarDesligarBuzzer() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Desligar o alarme dos aparelhos?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Os aparelhos vão parar de tocar a sirene de temperatura nas estufas. '
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
    if (_furaNaoPerturbe == true) {
      // Ja liberado: o metodo do plugin nao reabre as configuracoes (so as abre
      // quando a permissao ainda falta). Vamos direto pelo canal nativo, para o
      // produtor poder conferir ou revogar o acesso.
      await PushNotificationService.instance.abrirAcessoNaoPerturbe();
    } else {
      await PushNotificationService.instance.solicitarPermissaoNaoPerturbe();
    }
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
    await _servico.atualizar(_servico.preferencias.comEvento(evento, nova));
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
            'Essa função não funciona no modo silencioso do celular.',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Alarme fisico (buzzer de temperatura), global: vale para todas as estufas.
  // Fogo nunca e afetado. Para desligar so uma, o produtor segura o botao do
  // buzzer naquele aparelho.
  Widget _cartaoAlarmeAparelho() {
    return AnimatedBuilder(
      animation: _buzzer,
      builder: (context, _) => Container(
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
                    'Alarme dos aparelhos',
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
              'Liga e desliga a sirene do alarme de temperatura em todos os '
              'aparelhos cadastrados no app. A sirene de aviso de incêndio '
              'ainda continua ligada.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Tocar nas estufas',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              value: _buzzer.ativo,
              onChanged: _mudarBuzzer,
            ),
          ],
        ),
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
                // Uma frase por linha: sao tres ideias independentes (o que
                // escolher, o alcance e a ressalva da internet), e emendadas
                // viravam um paragrafo que ninguem le ate o fim.
                const Text(
                  'Escolha que tipo de notificação deseja no seu celular.\n\n'
                  'As notificações são para todas as estufas cadastradas.\n\n'
                  'As notificações não serão enviadas caso o seu celular '
                  'esteja sem internet (Wi-Fi ou dados móveis).',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                for (final evento in EventoNotificacao.values)
                  _CartaoEvento(
                    evento: evento,
                    opcao: prefs.opcao(evento),
                    aoMudar: (nova, desligandoIncendio) =>
                        _mudar(evento, nova, desligandoIncendio),
                  ),
                _cartaoAlarmeAparelho(),
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
              'Tocar',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            // O rotulo era "Tocar / vibrar", o que sugeria mexer no bipe e na
            // vibracao comuns - esses seguem a configuracao do celular. Este
            // interruptor faz outra coisa: decide se o aviso toca como ALARME.
            subtitle: const Text(
              'Toca como alarme de aviso',
              style: TextStyle(color: Colors.white38, fontSize: 12),
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
