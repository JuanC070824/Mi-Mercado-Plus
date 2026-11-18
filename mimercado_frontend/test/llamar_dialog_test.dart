import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/features/casero/widgets/llamar_dialog.dart';

Future<void> _abrirDialogo(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                mostrarLlamar(context, nombre: 'María', celular: '900000001'),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  final original = abrirMarcador;
  tearDown(() => abrirMarcador = original);

  testWidgets('Llamar abre el marcador con el número del Perú', (tester) async {
    Uri? abierto;
    abrirMarcador = (uri) async {
      abierto = uri;
      return true;
    };
    await _abrirDialogo(tester);
    expect(find.text('Llamar a María'), findsOneWidget);
    await tester.tap(find.text('Llamar'));
    await tester.pumpAndSettle();
    expect(abierto.toString(), 'tel:+51900000001');
    expect(find.text('Llamar a María'), findsNothing);
  });

  testWidgets('si no hay marcador, copia el número y avisa', (tester) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    abrirMarcador = (_) async => false;
    await _abrirDialogo(tester);
    await tester.tap(find.text('Llamar'));
    await tester.pumpAndSettle();
    expect(copiado, '900000001');
    expect(find.textContaining('Copiamos el número'), findsOneWidget);
  });
}
