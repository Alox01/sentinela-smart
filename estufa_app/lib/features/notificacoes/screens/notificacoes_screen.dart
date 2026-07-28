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

  String _modoDeSom = 'normal';

  @override
  void initState() {
    super.initState();
    unawaited(_buzzer.carregar());
    if (_ehAndroid) {
      unawaited(_conferirModoDeSom());
    }
  }

  Future<void> _conferirModoDeSom() async {
    final modo = await PushNotificationService.instance.modoDeSom();
    if (mounted) setState(() => _modoDeSom = modo);
  }

  /// Avisa que o celular esta mudo. E o estado mais perigoso para este app e o
  /// que se entra sem querer - baixando o volume, sobrando de uma reuniao -,
  /// entao dizer isso aqui vale mais do que uma legenda lida uma vez na
  /// instalacao.
  Widget _cartaoModoDeSom() {
    final silencioso = _modoDeSom == 'silencioso';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.volume_off_rounded,
            color: Colors.amberAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  silencioso
                      ? 'Seu celular está no silencioso'
                      : 'Seu celular está no modo vibrar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  silencioso
                      ? 'Nenhum aviso vai tocar, nem o de incêndio. Tire do '
                            'silencioso — se quiser sossego à noite, use o '
                            '"Não perturbe".'
                      : 'Os avisos não vão tocar, apenas vibrar. Tire do modo '
                            'vibrar para ouvir o alarme.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                if (_ehAndroid && _modoDeSom != 'normal') _cartaoModoDeSom(),
                for (final evento in EventoNotificacao.values)
                  _CartaoEvento(
                    evento: evento,
                    opcao: prefs.opcao(evento),
                    aoMudar: (nova, desligandoIncendio) =>
                        _mudar(evento, nova, desligandoIncendio),
                  ),
                _cartaoAlarmeAparelho(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'As notificações são do app, não do alarme do aparelho.\n\n'
                    'Com o celular no silencioso ou no vibrar, nenhum aviso '
                    'toca — nem o de incêndio. A sirene da estufa continua '
                    'tocando de qualquer jeito.',
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
