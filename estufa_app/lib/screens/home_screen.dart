import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../features/home/models/modelo_estufa.dart';
import '../features/home/services/estufas_repository.dart';
import '../features/home/widgets/adicionar_estufa_card.dart';
import '../features/home/widgets/estufa_resumo_card.dart';
import '../services/backup_file_service.dart';
import '../services/isar_service.dart';
import '../services/monitor_estufas.dart';
import 'estufa_form_screen.dart';

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
    final estufas = await _estufasRepository.listar();

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
                            childAspectRatio: 1.0,
                          ),
                      itemCount: minhasEstufas.length + 1,
                      itemBuilder: (context, index) {
                        if (index == minhasEstufas.length) {
                          return AdicionarEstufaCard(
                            onTap: () => _abrirFormularioEstufa(),
                          );
                        }
                        return EstufaResumoCard(
                          estufa: minhasEstufas[index],
                          onEditar: () => _abrirFormularioEstufa(
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

  Future<void> _abrirFormularioEstufa({ModeloEstufa? estufa}) async {
    final salvo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EstufaFormScreen(estufa: estufa)),
    );

    if (salvo != true || !mounted) return;
    await _carregarEstufas();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          estufa == null ? 'Estufa cadastrada.' : 'Estufa atualizada.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
    MonitorEstufas.instance.remover(estufa.id);
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

      if (kIsWeb) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup exportado.')),
        );
        return;
      }
      // Abre o compartilhamento nativo: o produtor pode salvar no Drive,
      // mandar por WhatsApp, e-mail, etc.
      await Share.shareXFiles(
        [XFile(destino, mimeType: 'application/json')],
        subject: 'Backup Sentinela Smart',
        text: 'Backup das estufas ($fileName).',
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Falha ao exportar backup: $e')),
      );
    }
  }

  Future<void> _importarBackup() async {
    final messenger = ScaffoldMessenger.of(context);

    final selecionado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (selecionado == null || selecionado.files.isEmpty) {
      return; // usuário cancelou
    }
    final bytes = selecionado.files.single.bytes;
    if (bytes == null) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível ler o arquivo.')),
      );
      return;
    }

    if (!mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Importar backup',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Isso vai substituir os dados atuais do app pelos do backup. Continuar?',
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
              'Importar',
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final jsonContent = utf8.decode(bytes);
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
