import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quais estufas estao com os avisos do app silenciados, por aparelho
/// (`idHardware`). Escopo por estufa — ao contrario das preferencias globais.
///
/// O fogo e o "sem comunicacao" NUNCA sao silenciados: mesmo com a estufa
/// silenciada, esses dois continuam avisando. So os demais avisos daquela
/// estufa param. A supressao acontece no servidor, que ja filtra por
/// preferencia de dispositivo; o app apenas registra, para a estufa silenciada,
/// um conjunto de preferencias reduzido.
class SilenciamentoEstufas extends ChangeNotifier {
  static const String _chave = 'estufas_avisos_silenciados_v1';

  static final SilenciamentoEstufas instance = SilenciamentoEstufas._();
  SilenciamentoEstufas._();

  final Set<String> _silenciadas = {};
  bool _carregado = false;

  bool get carregado => _carregado;

  Future<void> carregar() async {
    if (_carregado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chave);
      if (texto != null && texto.isNotEmpty) {
        final lista = jsonDecode(texto);
        if (lista is List) {
          _silenciadas.addAll(lista.whereType<String>());
        }
      }
    } catch (_) {
      // Sem preferencia salva: ninguem silenciado.
    }
    _carregado = true;
    notifyListeners();
  }

  bool silenciada(String? idHardware) =>
      idHardware != null && _silenciadas.contains(idHardware);

  Future<void> definir(String idHardware, bool silenciar) async {
    if (silenciar) {
      _silenciadas.add(idHardware);
    } else {
      _silenciadas.remove(idHardware);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, jsonEncode(_silenciadas.toList()));
    } catch (_) {
      // Persistir e melhor esforco: a UI ja refletiu a mudanca em memoria.
    }
  }
}
