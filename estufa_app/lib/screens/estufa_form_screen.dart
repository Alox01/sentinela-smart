import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/home/models/modelo_estufa.dart';
import '../features/home/services/estufas_repository.dart';
import '../services/isar_service.dart';
import '../utils/browser_text_input.dart';

class EstufaFormScreen extends StatefulWidget {
  final ModeloEstufa? estufa;

  const EstufaFormScreen({super.key, this.estufa});

  @override
  State<EstufaFormScreen> createState() => _EstufaFormScreenState();
}

class _EstufaFormScreenState extends State<EstufaFormScreen> {
  static const int _limiteNomeEstufa = 24;

  final EstufasRepository _repository = EstufasRepository(IsarService.instance);
  late final TextEditingController _nomeController;
  late final TextEditingController _ipController;
  late final TextEditingController _chaveController;

  bool _ocultarChave = true;
  bool _salvando = false;

  bool get _editando => widget.estufa != null;

  bool get _usarEntradaNativaWeb {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.estufa?.nome ?? '');
    _ipController = TextEditingController(text: widget.estufa?.ip ?? '');
    _chaveController = TextEditingController(
      text: widget.estufa?.tokenAcesso ?? '',
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _ipController.dispose();
    _chaveController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    final ip = _ipController.text.trim();
    final chaveTexto = _chaveController.text.trim();
    final chave = chaveTexto.isEmpty ? null : chaveTexto;

    if (nome.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome e o endereço da estufa.')),
      );
      return;
    }

    if (!_enderecoValido(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Endereço inválido. Use algo como 192.168.1.9 ou 192.168.1.9:80.',
          ),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _salvando = true);

    try {
      if (_editando) {
        await _repository.atualizar(
          id: widget.estufa!.id,
          nome: nome,
          ip: ip,
          tokenAcesso: chave,
        );
      } else {
        await _repository.salvar(nome: nome, ip: ip, tokenAcesso: chave);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a estufa. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // Validacao leve do endereco: aceita IP, nome de host (inclusive mDNS como
  // "sentinela.local"), com ou sem "http://" e com porta opcional. Rejeita so o
  // que e claramente invalido (espacos, caracteres estranhos, porta fora da
  // faixa). O ApiService ainda normaliza, entao isso e so um aviso amigavel.
  bool _enderecoValido(String enderecoBruto) {
    var valor = enderecoBruto.trim();
    if (valor.isEmpty) return false;

    valor = valor.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    valor = valor.split('/').first; // ignora caminho apos o host
    if (valor.isEmpty || valor.contains(' ')) return false;

    final partes = valor.split(':');
    if (partes.length > 2) return false; // mais de um ":"

    final host = partes[0];
    if (!RegExp(r'^[a-zA-Z0-9.\-]+$').hasMatch(host)) return false;

    if (partes.length == 2) {
      final porta = int.tryParse(partes[1]);
      if (porta == null || porta < 1 || porta > 65535) return false;
    }
    return true;
  }

  Future<void> _editarTextoNativo({
    required String titulo,
    required TextEditingController controller,
    int? limite,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final valor = await pedirTextoNativo(
      titulo: titulo,
      valorAtual: controller.text,
    );
    if (valor == null) return;

    final ajustado = limite == null || valor.length <= limite
        ? valor
        : valor.substring(0, limite);
    setState(() => controller.text = ajustado.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191D),
        foregroundColor: Colors.white,
        title: Text(_editando ? 'Editar estufa' : 'Adicionar estufa'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _editando ? 'Editar estufa' : 'Adicionar estufa',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_usarEntradaNativaWeb)
                      _buildEntradaNativaWeb()
                    else
                      _buildEntradaFlutter(),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _salvando
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('CANCELAR'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _salvando ? null : _salvar,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: const Color(0xFF102016),
                          ),
                          child: Text(_salvando ? 'SALVANDO...' : 'SALVAR'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntradaFlutter() {
    return Column(
      children: [
        _buildNomeField(),
        const SizedBox(height: 18),
        _buildIpField(),
        const SizedBox(height: 18),
        _buildChaveField(),
      ],
    );
  }

  Widget _buildEntradaNativaWeb() {
    final nome = _nomeController.text.trim();
    final ip = _ipController.text.trim();
    final chaveConfigurada = _chaveController.text.trim().isNotEmpty;

    return Column(
      children: [
        _buildCampoNativoCard(
          titulo: 'Nome',
          valor: nome.isEmpty ? 'Toque para informar' : nome,
          subtitulo: 'Use até 24 caracteres.',
          icone: Icons.badge_outlined,
          onTap: () => _editarTextoNativo(
            titulo: 'Nome da estufa',
            controller: _nomeController,
            limite: _limiteNomeEstufa,
          ),
        ),
        const SizedBox(height: 12),
        _buildCampoNativoCard(
          titulo: 'IP ou endereço',
          valor: ip.isEmpty ? 'Ex: 192.168.1.11' : ip,
          subtitulo: 'Endereço usado pelo aplicativo.',
          icone: Icons.router_outlined,
          onTap: () => _editarTextoNativo(
            titulo: 'IP ou endereço da estufa',
            controller: _ipController,
          ),
        ),
        const SizedBox(height: 12),
        _buildCampoNativoCard(
          titulo: 'Chave de acesso',
          valor: chaveConfigurada ? 'Configurada' : 'Opcional',
          subtitulo: 'Use a mesma chave configurada no aparelho.',
          icone: Icons.vpn_key_outlined,
          onTap: () => _editarTextoNativo(
            titulo: 'Chave de acesso',
            controller: _chaveController,
          ),
        ),
      ],
    );
  }

  Widget _buildCampoNativoCard({
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icone,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icone, color: Colors.white54, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'EDITAR',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNomeField() {
    return TextField(
      controller: _nomeController,
      textInputAction: TextInputAction.next,
      maxLength: _limiteNomeEstufa,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Nome (ex: Galpão 01)',
        helperText: 'Use até 24 caracteres.',
        helperStyle: TextStyle(color: Colors.white38),
        counterStyle: TextStyle(color: Colors.white38),
        labelStyle: TextStyle(color: Colors.white54),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildIpField() {
    return TextField(
      controller: _ipController,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.url,
      textCapitalization: TextCapitalization.none,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'IP ou endereço',
        hintText: 'Ex: 192.168.1.11',
        hintStyle: TextStyle(color: Colors.white30),
        labelStyle: TextStyle(color: Colors.white54),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildChaveField() {
    return TextField(
      controller: _chaveController,
      obscureText: _ocultarChave,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textCapitalization: TextCapitalization.none,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _salvar(),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Chave de acesso',
        hintText: 'Opcional',
        helperText: 'Use a mesma chave configurada no aparelho.',
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white38),
        suffixIcon: IconButton(
          tooltip: _ocultarChave ? 'Mostrar chave' : 'Ocultar chave',
          icon: Icon(
            _ocultarChave
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.white54,
          ),
          onPressed: () => setState(() => _ocultarChave = !_ocultarChave),
        ),
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white30),
        helperStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }
}
