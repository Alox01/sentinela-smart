import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Configura a rede e a chave do aparelho pelo app, sem digitar endereco.
///
/// O aparelho tambem serve a mesma pagina em `192.168.4.1`, e o portal cativo
/// tenta abri-la sozinha — mas quem decide isso e o Android, e nao ha garantia.
/// Esta tela e o caminho que sempre funciona: o produtor ja tem o app, e um
/// toque no menu basta.
class ConfigurarAparelhoScreen extends StatefulWidget {
  const ConfigurarAparelhoScreen({super.key});

  @override
  State<ConfigurarAparelhoScreen> createState() =>
      _ConfigurarAparelhoScreenState();
}

class _ConfigurarAparelhoScreenState extends State<ConfigurarAparelhoScreen> {
  // Endereco fixo do ponto de acesso do ESP32 (padrao do softAP).
  static const String _enderecoAparelho = 'http://192.168.4.1';

  final _rede = TextEditingController();
  final _senha = TextEditingController();
  final _chave = TextEditingController();

  bool _enviando = false;
  String? _erro;
  bool _concluido = false;

  @override
  void dispose() {
    _rede.dispose();
    _senha.dispose();
    _chave.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final rede = _rede.text.trim();
    if (rede.isEmpty) {
      setState(() => _erro = 'Informe o nome da rede Wi-Fi.');
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final resposta = await http
          .post(
            Uri.parse('$_enderecoAparelho/salvar'),
            // O aparelho le os campos com server.arg(), que espera formulario.
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'ssid': rede,
              'senha': _senha.text,
              'token': _chave.text.trim(),
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        setState(() => _concluido = true);
      } else {
        setState(
          () => _erro = 'O aparelho recusou (código ${resposta.statusCode}).',
        );
      }
    } catch (_) {
      if (!mounted) return;
      // A causa quase sempre e a mesma: o celular nao esta na rede do aparelho.
      setState(
        () => _erro =
            'Não encontrei o aparelho. Confirme que o celular está conectado '
            'na rede "Sentinela-Config" e que o visor mostra ConF.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191D),
        foregroundColor: Colors.white,
        title: const Text('Configurar aparelho'),
      ),
      body: SafeArea(child: _concluido ? _sucesso() : _formulario()),
    );
  }

  Widget _sucesso() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'Configuração enviada',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'O aparelho está reiniciando e vai entrar na rede nova. '
            'A rede "Sentinela-Config" vai sumir — reconecte o celular no '
            'Wi-Fi de sempre.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.greenAccent),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amberAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.3),
            ),
          ),
          child: const Text(
            'Antes de preencher:\n\n'
            '1. No aparelho, segure os três botões por 3 segundos até o visor '
            'mostrar ConF.\n'
            '2. No Wi-Fi do celular, conecte na rede "Sentinela-Config".\n'
            '3. O Android avisa que a rede não tem internet — aceite continuar '
            'conectado, senão ele volta para os dados móveis.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        _campo(
          controlador: _rede,
          rotulo: 'Rede Wi-Fi da propriedade',
          dica: 'Nome exato, com maiúsculas e minúsculas',
        ),
        _campo(
          controlador: _senha,
          rotulo: 'Senha do Wi-Fi',
          dica: 'Deixe vazio para manter a senha atual',
          senha: true,
        ),
        _campo(
          controlador: _chave,
          rotulo: 'Chave de acesso',
          dica: 'A mesma cadastrada na estufa, aqui no app',
        ),
        if (_erro != null) ...[
          const SizedBox(height: 16),
          Text(
            _erro!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _enviando ? null : _salvar,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _enviando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Salvar no aparelho'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'O aparelho reinicia sozinho depois de salvar. O alarme continua '
          'funcionando durante todo o processo.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _campo({
    required TextEditingController controlador,
    required String rotulo,
    required String dica,
    bool senha = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controlador,
        obscureText: senha,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: rotulo,
          labelStyle: const TextStyle(color: Colors.white54),
          helperText: dica,
          helperStyle: const TextStyle(color: Colors.white24, fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
