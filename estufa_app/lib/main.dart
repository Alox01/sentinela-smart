import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/agendamento/services/agendamento_service.dart';
import 'features/notificacoes/services/preferencias_notificacao_service.dart';
import 'features/notificacoes/services/push_notification_service.dart';
import 'screens/home_screen.dart';
import 'services/isar_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registrarTratamentoPushEmSegundoPlano();
  runApp(const EstufaApp());
}

class EstufaApp extends StatelessWidget {
  const EstufaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinela',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0E1012),
        primarySwatch: Colors.green,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const _BootstrapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _inicializar();
  }

  Future<void> _inicializar() async {
    // Preferencias de notificacao: carrega cedo para o app ja respeitar os
    // interruptores; nao bloqueia o boot se falhar.
    await PreferenciasNotificacaoService.instance.carregar();
    await IsarService.instance.init().timeout(const Duration(seconds: 20));
    await PushNotificationService.instance.inicializar();
    // Reagenda os avisos de ajuste: reiniciar o celular apaga os alarmes do
    // sistema, e nem todo fabricante entrega o BOOT_COMPLETED que o plugin
    // usa para se reerguer sozinho.
    unawaited(AgendamentoService.instance.carregar());
  }

  void _tentarNovamente() {
    setState(() {
      _initFuture = _inicializar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF0E1012),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.orangeAccent,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Falha ao iniciar o banco local.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No navegador, tente executar com: flutter run -d chrome --no-web-resources-cdn',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _tentarNovamente,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const HomeScreen();
      },
    );
  }
}
