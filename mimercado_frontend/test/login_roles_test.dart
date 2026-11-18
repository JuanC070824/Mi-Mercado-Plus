import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';

/// Entra desde la bienvenida con un perfil y devuelve cuando terminó de navegar.
Future<void> _ingresar(
  WidgetTester tester, {
  required String perfil,
  required String celular,
}) async {
  appRouter.go('/');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(perfil)); // la bienvenida tiene scroll
  await tester.tap(find.text(perfil));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), celular);
  await tester.enterText(find.byType(TextFormField).at(1), 'Mercado123');
  await tester.ensureVisible(find.text('Ingresar'));
  await tester.tap(find.text('Ingresar'));
  await tester.pump(const Duration(seconds: 2)); // espera del mock
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Pantalla de celular para que la bienvenida no desborde.
    final vista =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    vista.physicalSize = const Size(1080, 2400);
    vista.devicePixelRatio = 3;
  });

  Widget app() => MaterialApp.router(routerConfig: appRouter);

  testWidgets(
    'la casera Rosa entra a su menú: Inicio · Pedidos · Catálogo · Mi puesto',
    (tester) async {
      await tester.pumpWidget(app());
      await _ingresar(tester, perfil: 'Comerciante', celular: '912345678');

      expect(find.text('¡Hola, Rosa!'), findsOneWidget);
      for (final t in ['Pedidos', 'Catálogo', 'Mi puesto']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Canasta'), findsNothing);
    },
  );

  testWidgets(
    'repartidor sin conexión configurada no entra al prototipo con pedidos inventados',
    (tester) async {
      await tester.pumpWidget(app());
      await _ingresar(tester, perfil: 'Repartidor', celular: '923456789');

      expect(
        find.textContaining(
          'No está configurada la conexión al servicio de repartidores',
        ),
        findsOneWidget,
      );
      expect(find.text('¡Hola, Ernesto!'), findsNothing);
      expect(find.textContaining('Surquillo'), findsNothing);
      expect(find.textContaining('#344-B'), findsNothing);
    },
  );

  testWidgets('el celular de un cliente no entra como casero', (tester) async {
    await tester.pumpWidget(app());
    await _ingresar(tester, perfil: 'Comerciante', celular: '987654321');

    expect(find.textContaining('registrado como Cliente'), findsOneWidget);
    expect(find.text('Perfil: Comerciante'), findsOneWidget);
  });
}
