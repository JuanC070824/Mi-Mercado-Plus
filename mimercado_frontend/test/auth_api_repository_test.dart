import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/repositories/auth_api_repository.dart';

void main() {
  tearDown(SesionState.cerrar);

  test(
    'login real envía celular, contraseña y rol, y conserva el token',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.example.test/api/auth/login/',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['celular'], '900000011');
        expect(body['password'], 'ClaveSegura!42');
        expect(body['rol'], 'vendedor');
        return http.Response(
          jsonEncode({
            'token': 'token-firmado',
            'token_type': 'Bearer',
            'expires_in': 3600,
            'rol_activo': 'vendedor',
            'usuario': {
              'id': 2,
              'nombres': 'Rosa',
              'celular': '900000011',
              'correo': 'rosa@example.test',
              'roles': ['vendedor'],
              'puesto_id': 7,
              'mercado_id': 3,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = AuthApiRepository(
        client: client,
        baseUrl: 'https://api.example.test',
      );

      final resultado = await repo.iniciarSesion(
        celular: '900000011',
        password: 'ClaveSegura!42',
        rol: Rol.comerciante,
      );

      expect(resultado.exito, isTrue);
      expect(resultado.usuario?.nombres, 'Rosa');
      expect(resultado.usuario?.puestoId, 7);
      expect(resultado.usuario?.mercadoId, 3);
      expect(SesionState.activa, isTrue);
      expect(SesionState.token, 'token-firmado');
    },
  );

  test('login muestra el mensaje seguro enviado por el backend', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'detail': 'Celular o contraseña incorrectos.'}),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );
    final repo = AuthApiRepository(
      client: client,
      baseUrl: 'https://api.example.test',
    );

    final resultado = await repo.iniciarSesion(
      celular: '900000101',
      password: 'incorrecta',
      rol: Rol.cliente,
    );

    expect(resultado.exito, isFalse);
    expect(resultado.mensaje, 'Celular o contraseña incorrectos.');
    expect(SesionState.activa, isFalse);
  });

  test('registro real envía DNI validado y el rol seleccionado', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://api.example.test/api/auth/registro/',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['dni'], '12345678');
      expect(body['dni_token'], 'consulta-firmada');
      expect(body['rol'], 'repartidor');
      expect(body['password'], 'ClaveSegura!42');
      return http.Response(
        jsonEncode({
          'token': 'token-registro',
          'expires_in': 3600,
          'rol_activo': 'repartidor',
          'usuario': {
            'id': 9,
            'nombres': 'Juan Carlos',
            'apellido_paterno': 'Quispe',
            'apellido_materno': 'Mamani',
            'celular': '923456781',
            'correo': null,
            'roles': ['repartidor'],
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final repo = AuthApiRepository(
      client: client,
      baseUrl: 'https://api.example.test',
    );

    final resultado = await repo.registrarUsuario(
      dni: '12345678',
      dniToken: 'consulta-firmada',
      usuario: const Usuario(
        nombres: 'Juan Carlos',
        apellidoPaterno: 'Quispe',
        apellidoMaterno: 'Mamani',
        celular: '923456781',
        rol: Rol.repartidor,
      ),
      password: 'ClaveSegura!42',
    );

    expect(resultado.exito, isTrue);
    expect(resultado.usuario?.rol, Rol.repartidor);
    expect(resultado.usuario?.apellidoPaterno, 'Quispe');
    expect(SesionState.token, 'token-registro');
  });
}
