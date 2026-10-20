import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_api_repository.dart';

void main() {
  test('obtiene mercados reales y conserva coordenadas opcionales', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://api.example.test/api/mercados/');
      return http.Response(
        jsonEncode([
          {
            'id': 21,
            'nombre': 'Mercado Central',
            'direccion': 'Av. Principal 123',
            'distrito': 'Lima',
            'provincia': 'Lima',
            'departamento': 'Lima',
            'latitud': '-12.050000',
            'longitud': '-77.040000',
          },
          {
            'id': 22,
            'nombre': 'Mercado sin coordenadas',
            'direccion': 'Jr. Prueba 456',
            'distrito': null,
            'provincia': null,
            'departamento': null,
            'latitud': null,
            'longitud': null,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repo = CatalogoApiRepository(
      client: client,
      baseUrl: 'https://api.example.test',
    );

    final resultado = await repo.mercados(
      latitud: -12.051,
      longitud: -77.041,
    );

    expect(resultado, hasLength(2));
    expect(resultado.first.mercado.id, 21);
    expect(resultado.first.distanciaKm, isNotNull);
    expect(resultado.last.mercado.id, 22);
    expect(resultado.last.distanciaKm, isNull);
  });
}
