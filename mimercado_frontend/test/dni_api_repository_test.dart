import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/data/repositories/dni_repository.dart';

void main() {
  test(
    'consulta DNI mediante el backend y conserva el token de registro',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.example.test/api/auth/dni/',
        );
        expect(jsonDecode(request.body), {'dni': '12345678'});
        return http.Response(
          jsonEncode({
            'nombres': 'María Esperanza',
            'apellido_paterno': 'Del Pilar',
            'apellido_materno': 'López',
            'registro_token': 'token-firmado',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = DniApiRepository(
        client: client,
        baseUrl: 'https://api.example.test',
      );

      final resultado = await repo.consultar('12345678');

      expect(resultado.estado, EstadoConsulta.encontrado);
      expect(resultado.datos?.nombres, 'María Esperanza');
      expect(resultado.datos?.registroToken, 'token-firmado');
    },
  );

  test('DNI inexistente se diferencia de una falla del servicio', () async {
    final repo = DniApiRepository(
      client: MockClient((_) async => http.Response('{}', 404)),
      baseUrl: 'https://api.example.test',
    );

    expect(
      (await repo.consultar('00000000')).estado,
      EstadoConsulta.noEncontrado,
    );
  });
}
