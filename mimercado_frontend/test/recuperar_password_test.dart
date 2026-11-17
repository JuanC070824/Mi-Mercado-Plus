import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/repositories/auth_api_repository.dart';
import 'package:mimercado_frontend/features/auth/screens/recuperar_password_screen.dart';

Future<void> _abrir(WidgetTester tester, AuthApiRepository repo) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/recuperar',
    routes: [
      GoRoute(
        path: '/recuperar',
        builder: (_, _) => RecuperarPasswordScreen(repository: repo),
      ),
      GoRoute(
        path: '/cliente/login',
        builder: (_, _) => const Scaffold(body: Text('PANTALLA LOGIN')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, int campo, String texto) async {
  final f = find.byType(TextFormField).at(campo);
  await tester.ensureVisible(f);
  await tester.enterText(f, texto);
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recupera la contraseña en 2 pasos y vuelve al login', (
    tester,
  ) async {
    final enviados = <String, Map>{};
    final repo = AuthApiRepository(
      baseUrl: 'http://localhost',
      client: MockClient((r) async {
        enviados[r.url.path] = jsonDecode(r.body) as Map;
        return http.Response(
          jsonEncode(
            r.url.path.endsWith('recuperar/')
                ? {'detail': 'ok', 'codigo_demostracion': '482913'}
                : {'detail': 'Listo, tu contraseña se cambió.'},
          ),
          200,
        );
      }),
    );
    await _abrir(tester, repo);
    expect(find.text('Paso 1 de 2'), findsOneWidget);
    await _escribir(tester, 0, '911111111');
    await _escribir(tester, 1, '12345678');
    await _tocar(tester, 'Continuar');
    expect(enviados['/api/auth/recuperar/'], {
      'celular': '911111111',
      'dni': '12345678',
    });
    expect(find.text('Paso 2 de 2'), findsOneWidget);
    expect(find.text('482913'), findsOneWidget);

    await _escribir(tester, 0, '482913');
    await _escribir(tester, 1, 'NuevaClave42');
    await _escribir(tester, 2, 'NuevaClave42');
    await _tocar(tester, 'Cambiar contraseña');
    expect(enviados['/api/auth/restablecer/'], {
      'celular': '911111111',
      'codigo': '482913',
      'password': 'NuevaClave42',
    });
    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
  });

  testWidgets('muestra el error del servidor y no avanza', (tester) async {
    var llamadas = 0;
    final repo = AuthApiRepository(
      baseUrl: 'http://localhost',
      client: MockClient((r) async {
        llamadas++;
        return http.Response(
          jsonEncode({
            'detail': 'El celular y el DNI no corresponden a una misma cuenta.',
          }),
          400,
        );
      }),
    );
    await _abrir(tester, repo);
    await _tocar(tester, 'Continuar');
    expect(llamadas, 0); // campos vacíos: no se envía nada
    await _escribir(tester, 0, '911111111');
    await _escribir(tester, 1, '87654321');
    await _tocar(tester, 'Continuar');
    expect(llamadas, 1);
    expect(find.textContaining('no corresponden'), findsOneWidget);
    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
