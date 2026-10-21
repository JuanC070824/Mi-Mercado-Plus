import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/features/casero/screens/casero_inicio_screen.dart';

void main() {
  testWidgets('muestra el estado real cuando el vendedor aún no tiene puesto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CaseroInicioScreen(
          usuario: Usuario(
            nombres: 'Gabriel',
            celular: '910023101',
            rol: Rol.comerciante,
          ),
        ),
      ),
    );

    expect(find.text('¡Hola, Gabriel!'), findsOneWidget);
    expect(find.text('Espacio para la foto de tu puesto'), findsOneWidget);
    expect(find.text('Aún no tienes un puesto'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Crear mi puesto'),
      findsOneWidget,
    );
    expect(find.textContaining('Doña Rosa'), findsNothing);
    expect(find.textContaining('Pedido de María'), findsNothing);
  });

  testWidgets('el vendedor sin puesto puede abrir su registro desde Inicio', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const CaseroInicioScreen(
            usuario: Usuario(
              nombres: 'Gabriel',
              celular: '910023101',
              rol: Rol.comerciante,
            ),
          ),
        ),
        GoRoute(
          path: '/casero/puesto',
          builder: (_, _) =>
              const Scaffold(body: Text('Formulario de mi puesto')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      );
      final boton = find.widgetWithText(FilledButton, 'Crear mi puesto');
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('Formulario de mi puesto'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/casero/puesto');
    } finally {
      semantics.dispose();
    }
  });
}
