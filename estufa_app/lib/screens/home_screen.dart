import 'dart:async';

import 'package:flutter/material.dart';

import '../features/home/models/convite_estufa.dart';
import '../features/home/models/modelo_estufa.dart';
import '../features/home/services/estufas_repository.dart';
import '../features/home/widgets/adicionar_estufa_card.dart';
import '../features/home/widgets/estufa_resumo_card.dart';
import '../features/home/widgets/ouvinte_convite_link.dart';
import '../features/notificacoes/screens/notificacoes_screen.dart';
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
    // O ouvinte fica aqui, e nao acima do `MaterialApp`, para reusar este
    // caminho inteiro: o mesmo formulario, a mesma recarga da lista e o mesmo
    // aviso de "Estufa cadastrada" do botao "Adicionar estufa". Um convite que
    // chega pelo QR nao deveria terminar diferente de um digitado a mao.
    return OuvinteConviteLink(
      aoReceber: (convite) => _abrirFormularioEstufa(convite: convite),
      child: _buildHome(context),
    );
  }

  Widget _buildHome(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0E1012),
        elevation: 0,
        actions: [
          // "Configurar aparelho" na primeira vez vive dentro de "Adicionar
          // estufa" (é onde o iniciante chega); para reconfigurar, no menu da
          // estufa. Não precisa de um ícone solto aqui na home.
          // As preferencias de notificacao sao globais, entao o lugar natural
          // delas e aqui, na lista de todas as estufas. Pelo menu de uma estufa
          // so, o produtor esperaria que valessem apenas para aquela.
          IconButton(
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white70,
            ),
            tooltip: 'Notificações',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificacoesScreen()),
            ),
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
      // Protege o fim da lista da barra de navegacao do sistema: sem isto o
      // ultimo cartao fica atras dela e nao aceita toque.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MINHAS ESTUFAS',
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
                            aoVoltar: () => unawaited(_carregarEstufas()),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirFormularioEstufa({
    ModeloEstufa? estufa,
    ConviteEstufa? convite,
  }) async {
    final resultado = await Navigator.of(context).push<ResultadoFormEstufa>(
      MaterialPageRoute(
        builder: (_) => EstufaFormScreen(estufa: estufa, convite: convite),
      ),
    );

    if (resultado == null || !mounted) return;
    await _carregarEstufas();
    if (!mounted) return;

    // Quem diz o que aconteceu e o formulario, nao esta tela: um convite de
    // aparelho ja cadastrado entra por "Adicionar estufa" e termina em
    // atualizacao, e anunciar "cadastrada" ali seria contar outra historia.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado == ResultadoFormEstufa.cadastrada
              ? 'Estufa cadastrada.'
              : 'Estufa atualizada.',
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


}
