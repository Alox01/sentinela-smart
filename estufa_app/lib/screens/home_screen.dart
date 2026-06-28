import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../features/home/models/modelo_estufa.dart';
import '../features/home/services/estufas_repository.dart';
import '../features/home/widgets/adicionar_estufa_card.dart';
import '../features/home/widgets/estufa_resumo_card.dart';
import '../services/backup_file_service.dart';
import '../services/isar_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EstufasRepository _estufasRepository = EstufasRepository(
    IsarService.instance,
  );
  List<ModeloEstufa> minhasEstufas = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarEstufas();
  }

  Future<void> _carregarEstufas() async {
    var estufas = await _estufasRepository.listar();

    if (estufas.isEmpty) {
      await _estufasRepository.salvar(
        nome: 'Estufa Principal',
        ip: 'localhost',
      );
      estufas = await _estufasRepository.listar();
    }

    if (!mounted) return;
    setState(() {
      minhasEstufas = estufas;
      carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0E1012),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.storage_rounded, color: Colors.white70),
            tooltip: 'Dados locais',
            onSelected: (value) async {
              if (value == 'exportar') {
                await _exportarBackup();
              } else if (value == 'importar') {
                await _importarBackup();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'exportar',
                child: Text('Exportar backup'),
              ),
              PopupMenuItem<String>(
                value: 'importar',
                child: Text('Importar backup'),
              ),
            ],
          ),
        ],
        title: Column(
          children: [
            const Text(
              'SENTINELA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                fontSize: 22,
              ),
            ),
            Text(
              'SISTEMA DE CURA',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MEUS GALPÕES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: carregando
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 1.1,
                          ),
                      itemCount: minhasEstufas.length + 1,
                      itemBuilder: (context, index) {
                        if (index == minhasEstufas.length) {
                          return AdicionarEstufaCard(
                            onTap: () => _mostrarDialogoCadastro(),
                          );
                        }
                        return EstufaResumoCard(
                          estufa: minhasEstufas[index],
                          onEditar: () => _mostrarDialogoCadastro(
                            estufa: minhasEstufas[index],
                          ),
                          onRemover: () =>
                              _confirmarRemocaoEstufa(minhasEstufas[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoCadastro({ModeloEstufa? estufa}) {
    const limiteNomeEstufa = 24;
    final editando = estufa != null;
    final nomeController = TextEditingController(text: estufa?.nome ?? '');
    final ipController = TextEditingController(text: estufa?.ip ?? '');
    final tokenController = TextEditingController(
      text: estufa?.tokenAcesso ?? '',
    );
    final nomeFocus = FocusNode();
    final ipFocus = FocusNode();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final media = MediaQuery.of(context);
            final alturaMaxima = media.size.height * 0.88;
            final chaveConfigurada = tokenController.text.trim().isNotEmpty;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 520,
                      maxHeight: alturaMaxima,
                    ),
                    child: Material(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(28),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              editando ? 'Editar Estufa' : 'Adicionar Estufa',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: nomeController,
                              focusNode: nomeFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => ipFocus.requestFocus(),
                              maxLength: limiteNomeEstufa,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.enforced,
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Nome (ex: Galp\u00E3o 01)',
                                helperText: 'Use at\u00E9 24 caracteres.',
                                helperStyle: TextStyle(color: Colors.white38),
                                counterStyle: TextStyle(color: Colors.white38),
                                labelStyle: TextStyle(color: Colors.white54),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: ipController,
                              focusNode: ipFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              keyboardType: TextInputType.url,
                              textCapitalization: TextCapitalization.none,
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'IP ou endere\u00E7o',
                                hintText: 'Ex: 192.168.1.11',
                                hintStyle: TextStyle(color: Colors.white30),
                                labelStyle: TextStyle(color: Colors.white54),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                final novaChave =
                                    await _mostrarDialogoChaveAcesso(
                                      context,
                                      tokenController.text,
                                    );
                                if (novaChave == null) return;
                                setDialogState(() {
                                  tokenController.text = novaChave.trim();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.vpn_key_outlined,
                                      color: chaveConfigurada
                                          ? Colors.greenAccent
                                          : Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Chave de acesso',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            chaveConfigurada
                                                ? 'Configurada para esta estufa.'
                                                : 'Opcional. Toque para definir.',
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      chaveConfigurada ? 'ALTERAR' : 'DEFINIR',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'CANCELAR',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () async {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    final nome = nomeController.text.trim();
                                    final ip = ipController.text.trim();
                                    final tokenTexto = tokenController.text
                                        .trim();
                                    final token = tokenTexto.isEmpty
                                        ? null
                                        : tokenTexto;

                                    if (nome.isEmpty || ip.isEmpty) return;

                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    Navigator.of(context).pop();

                                    if (editando) {
                                      await _estufasRepository.atualizar(
                                        id: estufa.id,
                                        nome: nome,
                                        ip: ip,
                                        tokenAcesso: token,
                                      );
                                    } else {
                                      await _estufasRepository.salvar(
                                        nome: nome,
                                        ip: ip,
                                        tokenAcesso: token,
                                      );
                                    }

                                    if (!mounted) return;
                                    await _carregarEstufas();
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          token == null
                                              ? 'Estufa salva sem chave de acesso.'
                                              : 'Estufa salva com chave de acesso.',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'SALVAR',
                                    style: TextStyle(color: Colors.greenAccent),
                                  ),
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
          },
        );
      },
    );
  }

  Future<String?> _mostrarDialogoChaveAcesso(
    BuildContext context,
    String valorAtual,
  ) async {
    final controller = TextEditingController(text: valorAtual);
    var ocultarChave = true;

    final resultado = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            'Chave de acesso',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: ocultarChave,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.none,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ex: 123456',
              helperText: 'Use a mesma chave configurada no aparelho.',
              helperMaxLines: 2,
              suffixIcon: IconButton(
                tooltip: ocultarChave ? 'Mostrar chave' : 'Ocultar chave',
                icon: Icon(
                  ocultarChave
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white54,
                ),
                onPressed: () {
                  setDialogState(() => ocultarChave = !ocultarChave);
                },
              ),
            ),
            onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return resultado;
  }

  Future<void> _confirmarRemocaoEstufa(ModeloEstufa estufa) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Remover Estufa',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remover "${estufa.nome}" da lista local?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remover',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    await _estufasRepository.remover(estufa.id);
    await _carregarEstufas();
  }

  Future<void> _exportarBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await IsarService.instance.exportarBackupJson();
      final fileName =
          'backup_estufa_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      final destino = await salvarBackupJson(
        fileNameBase: fileName,
        jsonContent: json,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Backup salvo: $destino')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Falha ao exportar backup: $e')),
      );
    }
  }

  Future<void> _importarBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final jsonContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Importar backup',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Cole aqui o JSON do backup',
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (jsonContent == null || jsonContent.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Importação cancelada.')),
      );
      return;
    }

    try {
      final resultado = await IsarService.instance.importarBackupJson(
        jsonContent,
        substituirTudo: true,
      );
      await _carregarEstufas();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Backup importado: ${resultado.estufasImportadas} estufas, ${resultado.ciclosImportados} ciclos, ${resultado.eventosImportados} eventos, ${resultado.leiturasImportadas} leituras, ${resultado.pendenciasImportadas} pendências.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Falha ao importar backup: $e')),
      );
    }
  }
}
