import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/data/repositories/puesto_vendedor_repository.dart';

void main() {
  tearDown(SesionState.cerrar);

  test('carga mercados, categorías y el estado vacío desde la API', () async {
    SesionState.iniciar(token: 'token-vendedor', expiresIn: 3600);
    final client = MockClient((request) async {
      if (request.url.path == '/api/mercados/') {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'nombre': 'Mercado Central',
              'direccion': 'Av. Principal 123',
              'distrito': 'Lima',
            },
          ]),
          200,
        );
      }
      if (request.url.path == '/api/categorias/') {
        return http.Response(
          jsonEncode([
            {'id': 2, 'nombre': 'Verduras y frutas'},
          ]),
          200,
        );
      }
      expect(request.headers['Authorization'], 'Bearer token-vendedor');
      return http.Response(
        jsonEncode({'tiene_puesto': false, 'puesto': null}),
        200,
      );
    });
    final repo = PuestoVendedorApiRepository(
      client: client,
      baseUrl: 'https://api.example.test',
    );

    final datos = await repo.cargar();

    expect(datos.puesto, isNull);
    expect(datos.mercados.single.direccion, 'Av. Principal 123');
    expect(datos.categorias.single.nombre, 'Verduras y frutas');
  });

  test(
    'crea el puesto enviando mercado, categoría y referencia reales',
    () async {
      SesionState.iniciar(token: 'token-vendedor', expiresIn: 3600);
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/vendedor/puesto/');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['mercado_id'], 1);
        expect(body['categoria_id'], 2);
        expect(body['referencia'], 'Pasillo 2');
        return http.Response(
          jsonEncode({
            'id': 8,
            'nombre': 'Verdulería Gabriel',
            'numero': 'A-12',
            'referencia': 'Pasillo 2',
            'foto_url': null,
            'abierto': false,
            'mercado': {
              'id': 1,
              'nombre': 'Mercado Central',
              'direccion': 'Av. Principal 123',
              'distrito': 'Lima',
            },
            'categoria': {'id': 2, 'nombre': 'Verduras y frutas'},
          }),
          201,
        );
      });
      final repo = PuestoVendedorApiRepository(
        client: client,
        baseUrl: 'https://api.example.test',
      );

      final puesto = await repo.guardar(
        puestoId: null,
        mercadoId: 1,
        categoriaId: 2,
        nombre: 'Verdulería Gabriel',
        numero: 'A-12',
        referencia: 'Pasillo 2',
      );

      expect(puesto.id, 8);
      expect(puesto.mercado.direccion, 'Av. Principal 123');
      expect(puesto.referencia, 'Pasillo 2');
    },
  );
}
