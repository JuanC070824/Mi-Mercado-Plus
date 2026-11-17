import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/app.dart';
import 'package:mimercado_frontend/core/i18n/idioma.dart';
import 'package:mimercado_frontend/core/i18n/traducciones_en.dart';
import 'package:mimercado_frontend/core/i18n/traducciones_qu.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _marcador = RegExp(r'\{\d+\}');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(reiniciarIdioma);

  test('en español devuelve el mismo texto y reemplaza los argumentos', () {
    expect(tr('Hola, {0}', ['María']), 'Hola, María');
    expect(tr('Mi canasta'), 'Mi canasta');
  });

  test('en inglés y quechua traduce, y lo que falta sale en español', () async {
    await IdiomaState.cambiar(Idioma.ingles);
    expect(tr('Mi canasta'), 'My basket');
    expect(tr('Hola, {0}', ['María']), 'Hi, María');
    expect(tr('Frase que no existe'), 'Frase que no existe');
    expect(EstadoPedido.enCamino.etiqueta, 'On the way');

    await IdiomaState.cambiar(Idioma.quechua);
    expect(tr('Mi canasta'), 'Isanqay');
    expect(EstadoPedido.enCamino.etiqueta, 'Ñanpiñan');
  });

  test('el idioma elegido se guarda para la próxima vez', () async {
    await IdiomaState.cambiar(Idioma.quechua);
    IdiomaState.actual.value = Idioma.espanol;
    await IdiomaState.cargar();
    expect(IdiomaState.actual.value, Idioma.quechua);
  });

  test(
    'cada traducción conserva los mismos datos variables que el español',
    () {
      for (final tabla in [traduccionesEn, traduccionesQu]) {
        for (final e in tabla.entries) {
          final esperado = _marcador.allMatches(e.key).map((m) => m[0]).toSet();
          final obtenido = _marcador
              .allMatches(e.value)
              .map((m) => m[0])
              .toSet();
          expect(obtenido, esperado, reason: '"${e.key}" -> "${e.value}"');
        }
      }
    },
  );

  testWidgets('desde la bienvenida se cambia a inglés y a runasimi', (
    tester,
  ) async {
    final vista =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    vista.physicalSize = const Size(1080, 2400);
    vista.devicePixelRatio = 3;
    addTearDown(vista.reset);

    await tester.pumpWidget(const MiMercadoApp());
    appRouter.go('/');
    await tester.pumpAndSettle();
    expect(find.text('Soy:'), findsOneWidget);

    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('I am:'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Runasimi'));
    await tester.pumpAndSettle();
    expect(find.text('Ñuqaqa kani:'), findsOneWidget);
    expect(find.text('Rantiq'), findsOneWidget);
  });
}
