import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/app.dart';
import 'package:mimercado_frontend/core/i18n/idioma.dart';
import 'package:mimercado_frontend/core/i18n/traducciones_ay.dart';
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

  test('en quechua y aimara traduce, y lo que falta sale en español', () async {
    await IdiomaState.cambiar(Idioma.aimara);
    expect(tr('Mi canasta'), 'Kanastaja');
    expect(tr('Hola, {0}', ['María']), 'Kamisaki, María');
    expect(tr('Frase que no existe'), 'Frase que no existe');
    expect(EstadoPedido.enCamino.etiqueta, 'Thakhinkiwa');

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
      for (final tabla in [traduccionesQu, traduccionesAy]) {
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

  testWidgets('desde la bienvenida se cambia a quechua y a aimara', (
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
    await tester.tap(find.text('Quechua'));
    await tester.pumpAndSettle();
    expect(find.text('Ñuqaqa kani:'), findsOneWidget);
    expect(find.text('Rantiq'), findsOneWidget);

    await tester.tap(find.text('Quechua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aymara'));
    await tester.pumpAndSettle();
    expect(find.text('Nayax:'), findsOneWidget);
    expect(find.text('Alasiri'), findsOneWidget);
  });
}
