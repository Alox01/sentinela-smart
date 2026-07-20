import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:estufa_app/main.dart';

void main() {
  testWidgets('mostra carregamento durante o bootstrap do app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EstufaApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Remove a arvore antes de encerrar para nao deixar o bootstrap assincrono
    // preso ao teste.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
