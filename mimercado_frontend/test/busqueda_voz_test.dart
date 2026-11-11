import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/utils/voz_service.dart';
import 'package:mimercado_frontend/features/mercado/widgets/escuchar_voz_dialog.dart';

class _VozFalsa implements VozService {
  void Function(String, bool)? oir;
  int detenciones = 0;
  @override
  Future<bool> preparar() async => true;
  @override
  Future<void> escuchar(void Function(String texto, bool fin) alOir) async =>
      oir = alOir;
  @override
  Future<void> detener() async => detenciones++;
}

Future<Future<String?> Function()> _abrir(
  WidgetTester tester,
  VozService voz,
) async {
  String? resultado;
  var listo = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await escucharBusqueda(context, voz);
              listo = true;
            },
            child: const Text('mic'),
          ),
        ),
      ),
    ),
  );
  return () async => listo ? resultado : 'SIN CERRAR';
}

void main() {
  testWidgets('muestra lo que entiende y busca con el resultado final', (
    tester,
  ) async {
    final voz = _VozFalsa();
    final resultado = await _abrir(tester, voz);
    await tester.tap(find.text('mic'));
    await tester.pumpAndSettle();
    expect(find.text('Te escucho…'), findsOneWidget);
    voz.oir!('pollo', false);
    await tester.pump();
    expect(find.text('“pollo”'), findsOneWidget);
    voz.oir!('pollo fresco', true);
    await tester.pumpAndSettle();
    expect(find.text('Te escucho…'), findsNothing);
    expect(await resultado(), 'pollo fresco');
    expect(voz.detenciones, 1);
  });

  testWidgets('cancelar no busca nada y apaga el micrófono', (tester) async {
    final voz = _VozFalsa();
    final resultado = await _abrir(tester, voz);
    await tester.tap(find.text('mic'));
    await tester.pumpAndSettle();
    voz.oir!('tom', false);
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await resultado(), isNull);
    expect(voz.detenciones, 1);
  });
}
