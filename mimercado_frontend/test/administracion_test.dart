import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/repositories/administracion_api_repository.dart';
import 'package:mimercado_frontend/features/administracion/screens/admin_screen.dart';

Map<String, dynamic> _solicitud({
  bool autorizado = false,
  bool enCurso = false,
}) => {
  'id': 5,
  'nombre': 'Pedro Ruiz',
  'celular': '987654321',
  'mercado': {'id': 3, 'nombre': 'Mercado Central'},
  'movilidad': 'moto',
  'placa': 'AB-123',
  'autorizado': autorizado,
  'entrega_en_curso': enCurso,
};

final _mercado = {
  'id': 3,
  'nombre': 'Mercado Central',
  'direccion': 'Av. Lima 123',
  'distrito': 'Cercado',
  'estado': 'activo',
  'puestos': 12,
};

void main() {
  setUp(() => SesionState.iniciar(token: 'tk', expiresIn: 3600));
  tearDown(SesionState.cerrar);

  group('AdministracionApiRepository', () {
    test('lista solicitudes y autoriza con el token del admin', () async {
      final pedidas = <http.Request>[];
      final repo = AdministracionApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          pedidas.add(r);
          if (r.method == 'GET') {
            return http.Response(jsonEncode([_solicitud()]), 200);
          }
          return http.Response(jsonEncode(_solicitud(autorizado: true)), 200);
        }),
      );
      final l = await repo.solicitudes();
      expect(l.single.nombre, 'Pedro Ruiz');
      expect(l.single.mercado, 'Mercado Central');
      expect(l.single.autorizado, isFalse);

      await repo.autorizar(5, autorizar: true);
      await repo.autorizar(5, autorizar: false);
      expect(pedidas.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/administracion/repartidores/',
        'POST /api/administracion/repartidores/5/autorizar/',
        'POST /api/administracion/repartidores/5/quitar/',
      ]);
      expect(
        pedidas.every((r) => r.headers['Authorization'] == 'Bearer tk'),
        isTrue,
      );
    });

    test('crea y edita mercados; muestra el motivo del servidor', () async {
      final cuerpos = <String, dynamic>{};
      final repo = AdministracionApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          cuerpos['${r.method} ${r.url.path}'] = jsonDecode(r.body);
          if (r.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'nombre': ['Ya existe un mercado con ese nombre.'],
              }),
              400,
            );
          }
          return http.Response(jsonEncode(_mercado), 201);
        }),
      );
      await repo.crearMercado(nombre: 'Nuevo', direccion: 'Jr. Uno 1');
      expect(cuerpos['POST /api/administracion/mercados/'], {
        'nombre': 'Nuevo',
        'direccion': 'Jr. Uno 1',
        'distrito': '',
      });
      await expectLater(
        repo.editarMercado(3, {'estado': 'suspendido'}),
        throwsA(
          isA<AdministracionException>().having(
            (e) => e.mensaje,
            'mensaje',
            'Ya existe un mercado con ese nombre.',
          ),
        ),
      );
      expect(cuerpos['PATCH /api/administracion/mercados/3/'], {
        'estado': 'suspendido',
      });
    });

    test('sin sesión no llama al servidor', () async {
      SesionState.cerrar();
      var llamadas = 0;
      final repo = AdministracionApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          llamadas++;
          return http.Response('[]', 200);
        }),
      );
      await expectLater(
        repo.mercados(),
        throwsA(isA<AdministracionException>()),
      );
      expect(llamadas, 0);
    });
  });

  testWidgets('el admin autoriza a un repartidor y ve sus mercados', (
    tester,
  ) async {
    var autorizado = false;
    final repo = AdministracionApiRepository(
      baseUrl: 'http://localhost',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/autorizar/')) {
          autorizado = true;
          return http.Response(jsonEncode(_solicitud(autorizado: true)), 200);
        }
        if (r.url.path.contains('mercados')) {
          return http.Response(jsonEncode([_mercado]), 200);
        }
        return http.Response(
          jsonEncode([_solicitud(autorizado: autorizado)]),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          usuario: const Usuario(
            nombres: 'Ana Torres',
            celular: '900000099',
            rol: Rol.administrador,
          ),
          alCerrarSesion: () {},
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
    expect(find.text('Pendiente de autorizar'), findsOneWidget);

    await tester.tap(find.text('Autorizar'));
    await tester.pumpAndSettle();
    expect(autorizado, isTrue);
    expect(find.text('Quitar autorización'), findsOneWidget);

    await tester.tap(find.text('Mercados'));
    await tester.pumpAndSettle();
    expect(find.text('Mercado Central'), findsWidgets);
    expect(find.text('Activo'), findsOneWidget);
  });
}
