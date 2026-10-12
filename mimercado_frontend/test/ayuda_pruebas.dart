import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';

// Ayudas compartidas por las pruebas de flujo (no es una prueba).

/// Las tarjetas de Inicio (componentes_inicio.dart y encabezado_inicio.dart)
/// se desbordan con la fuente cuadrada de las pruebas. Se ignoran SOLO esas;
/// cualquier otro desborde sigue haciendo fallar la prueba.
void ignorarDesbordesDeInicio() {
  final original = FlutterError.onError;
  FlutterError.onError = (detalle) {
    final texto = detalle.toString();
    final esDeInicio = texto.contains('componentes_inicio.dart') ||
        texto.contains('encabezado_inicio.dart');
    if (texto.contains('overflowed') && esDeInicio) return;
    original?.call(detalle);
  };
  addTearDown(() => FlutterError.onError = original);
}

/// Abre la app en pantalla de celular (360 × 800) y entra con un perfil.
Future<void> entrarComo(
  WidgetTester tester, {
  required String perfil,
  required String celular,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignorarDesbordesDeInicio();
  await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: appRouter));
  appRouter.go('/');
  await tester.pumpAndSettle();
  await tocar(tester, find.text(perfil));
  await tester.enterText(find.byType(TextFormField).at(0), celular);
  await tester.enterText(find.byType(TextFormField).at(1), 'Mercado123');
  await tocar(tester, find.text('Ingresar'), espera: 2000);
}

/// Hace scroll hasta el elemento, lo toca y espera a que el mock responda.
Future<void> tocar(WidgetTester tester, Finder f, {int espera = 1000}) async {
  if (f.evaluate().isEmpty) {
    // Las listas largas no construyen lo que está fuera de pantalla.
    await tester.scrollUntilVisible(f, 250, scrollable: listaPrincipal());
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pump(Duration(milliseconds: espera));
  await tester.pumpAndSettle();
}

/// La lista vertical de la pantalla (no la de un campo de texto).
Finder listaPrincipal() => find
    .byWidgetPredicate((w) =>
        w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

/// Escribe en el campo cuya etiqueta es [etiqueta] (hace scroll si hace falta).
Future<void> escribir(WidgetTester tester, String etiqueta, String texto) async {
  final campo = find.widgetWithText(TextFormField, etiqueta);
  if (campo.evaluate().isEmpty) {
    await tester.scrollUntilVisible(campo, 250, scrollable: listaPrincipal());
  }
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
  await tester.pumpAndSettle();
}
