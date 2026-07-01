import 'dart:js_interop';

@JS('window.prompt')
external JSString? _prompt(JSString titulo, JSString valorAtual);

Future<String?> pedirTextoNativo({
  required String titulo,
  required String valorAtual,
}) async {
  return _prompt(titulo.toJS, valorAtual.toJS)?.toDart;
}
