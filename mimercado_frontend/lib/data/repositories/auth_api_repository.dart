import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/rol.dart';
import '../models/usuario.dart';
import 'auth_repository.dart';

class AuthApiRepository implements LoginRepository {
  AuthApiRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  static final AuthApiRepository instancia = AuthApiRepository();

  final http.Client _client;
  final String? _baseUrl;

  @override
  Future<ResultadoAuth> iniciarSesion({
    required String celular,
    required String password,
    required Rol rol,
  }) async {
    try {
      final response = await _client
          .post(
            ApiConfig.uri('/api/auth/login/', baseUrlOverride: _baseUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'celular': celular,
              'password': password,
              'rol': rol.codigoBd,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode != 200) {
        return ResultadoAuth.error(
          data['detail']?.toString() ??
              'No pudimos iniciar sesión. Revisa tus datos e inténtalo nuevamente.',
        );
      }

      final token = data['token']?.toString() ?? '';
      final usuarioJson = data['usuario'];
      if (token.isEmpty || usuarioJson is! Map<String, dynamic>) {
        return const ResultadoAuth.error(
          'El servidor devolvió una respuesta incompleta. Inténtalo nuevamente.',
        );
      }

      final usuario = Usuario(
        nombres: usuarioJson['nombres']?.toString() ?? '',
        celular: usuarioJson['celular']?.toString() ?? celular,
        correo: usuarioJson['correo']?.toString(),
        rol: rol,
        puestoId: (usuarioJson['puesto_id'] as num?)?.toInt(),
        mercadoId: (usuarioJson['mercado_id'] as num?)?.toInt(),
      );
      if (usuario.nombres.isEmpty) {
        return const ResultadoAuth.error(
          'El servidor no devolvió los datos del usuario.',
        );
      }

      SesionState.iniciar(
        token: token,
        expiresIn: (data['expires_in'] as num?)?.toInt() ?? 3600,
      );
      return ResultadoAuth.ok(usuario);
    } on TimeoutException {
      return const ResultadoAuth.error(
        'El servidor tardó demasiado en responder. Inténtalo nuevamente.',
      );
    } on http.ClientException {
      return const ResultadoAuth.error(
        'No pudimos conectarnos con MiMercado+. Revisa tu conexión.',
      );
    } on FormatException {
      return const ResultadoAuth.error(
        'El servidor devolvió una respuesta que no pudimos leer.',
      );
    } on StateError catch (error) {
      return ResultadoAuth.error(error.message);
    }
  }
}
