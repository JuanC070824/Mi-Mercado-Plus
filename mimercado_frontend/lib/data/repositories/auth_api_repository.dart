import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/direccion.dart';
import '../models/rol.dart';
import '../models/usuario.dart';
import 'auth_repository.dart';

class AuthApiRepository implements LoginRepository, RegistroRepository {
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
  }) => _enviarAuth(
    ruta: '/api/auth/login/',
    estadoExitoso: 200,
    rol: rol,
    celular: celular,
    body: {'celular': celular, 'password': password, 'rol': rol.codigoBd},
  );

  @override
  Future<ResultadoAuth> registrarUsuario({
    required String dni,
    required String dniToken,
    required Usuario usuario,
    required String password,
    Direccion? direccion,
  }) => _enviarAuth(
    ruta: '/api/auth/registro/',
    estadoExitoso: 201,
    rol: usuario.rol,
    celular: usuario.celular,
    body: {
      'dni': dni,
      'dni_token': dniToken,
      'celular': usuario.celular,
      'correo': usuario.correo ?? '',
      'password': password,
      'rol': usuario.rol.codigoBd,
      'fecha_nacimiento': usuario.fechaNacimiento
          ?.toIso8601String()
          .split('T')
          .first,
      'letra_grande': usuario.letraGrande,
      'sonido': usuario.sonido,
      'vibracion': usuario.vibracion,
      if (direccion != null)
        'direccion': {
          'direccion': direccion.direccion,
          'referencia': direccion.referencia,
          'latitud': direccion.latitud,
          'longitud': direccion.longitud,
        },
    },
  );

  Future<ResultadoAuth> _enviarAuth({
    required String ruta,
    required int estadoExitoso,
    required Rol rol,
    required String celular,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client
          .post(
            ApiConfig.uri(ruta, baseUrlOverride: _baseUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (response.statusCode != estadoExitoso) {
        return ResultadoAuth.error(_mensajeError(data));
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
        apellidoPaterno: usuarioJson['apellido_paterno']?.toString(),
        apellidoMaterno: usuarioJson['apellido_materno']?.toString(),
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

  String _mensajeError(Map<String, dynamic> data) {
    final detail = data['detail'];
    if (detail != null) return detail.toString();
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String && value.isNotEmpty) return value;
    }
    return 'No pudimos completar la operación. Revisa los datos e inténtalo nuevamente.';
  }
}
