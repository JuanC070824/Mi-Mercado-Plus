import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/direccion.dart';
import '../models/rol.dart';
import '../models/usuario.dart';
import 'auth_repository.dart';

class AuthApiRepository implements AuthRepository {
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

  @override
  Future<Direccion?> direccionPrincipal(String celular) async {
    final response = await _autenticada('GET', '/api/direcciones/');
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      throw StateError(_mensajeError(data));
    }
    if (decoded is! List || decoded.isEmpty) return null;
    final principal = decoded.cast<dynamic>().firstWhere(
      (item) => item is Map<String, dynamic> && item['principal'] == true,
      orElse: () => decoded.first,
    );
    if (principal is! Map<String, dynamic>) return null;
    return Direccion(
      etiqueta: principal['etiqueta']?.toString() ?? 'Casa',
      direccion: principal['direccion']?.toString() ?? '',
      referencia: principal['referencia']?.toString(),
      principal: principal['principal'] == true,
    );
  }

  @override
  Future<ResultadoAuth> actualizarPerfil({
    required String celularActual,
    required String celular,
    String? correo,
    Direccion? direccion,
    String? passwordActual,
  }) async {
    try {
      final body = <String, dynamic>{
        'celular': celular,
        'correo': correo ?? '',
      };
      if (passwordActual != null) {
        body['password_actual'] = passwordActual;
      }
      final response = await _autenticada('PATCH', '/api/auth/me/', body: body);
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (response.statusCode != 200) {
        return ResultadoAuth.error(_mensajeError(data));
      }
      if (direccion != null) {
        final direccionResponse = await _autenticada(
          'POST',
          '/api/direcciones/',
          body: {
            'etiqueta': direccion.etiqueta,
            'direccion': direccion.direccion,
            'referencia': direccion.referencia ?? '',
            'principal': true,
          },
        );
        if (direccionResponse.statusCode != 201) {
          return const ResultadoAuth.error(
            'Guardamos tu perfil, pero no pudimos guardar la dirección.',
          );
        }
      }
      return ResultadoAuth.ok(_usuarioDesdeJson(data, celular));
    } on TimeoutException {
      return const ResultadoAuth.error(
        'El servidor tardó demasiado en responder.',
      );
    } on FormatException {
      return const ResultadoAuth.error('El servidor devolvió datos inválidos.');
    } on StateError catch (error) {
      return ResultadoAuth.error(error.message);
    } catch (_) {
      return const ResultadoAuth.error(
        'No pudimos conectarnos con MiMercado+.',
      );
    }
  }

  @override
  Future<void> guardarPreferencias({
    required String celular,
    required bool sonido,
    required bool vibracion,
  }) async {
    final response = await _autenticada(
      'PATCH',
      '/api/auth/me/',
      body: {'sonido': sonido, 'vibracion': vibracion},
    );
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      throw StateError(_mensajeError(data));
    }
  }

  Future<http.Response> _autenticada(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    final token = SesionState.token;
    if (token == null) {
      throw StateError('Tu sesión venció. Vuelve a iniciar sesión.');
    }
    final request =
        http.Request(metodo, ApiConfig.uri(ruta, baseUrlOverride: _baseUrl))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          });
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 15));
    return await http.Response.fromStream(streamed);
  }

  Usuario _usuarioDesdeJson(Map<String, dynamic> data, String celular) {
    final roles = data['roles'];
    final codigo = roles is List && roles.isNotEmpty
        ? roles.first.toString()
        : Rol.cliente.codigoBd;
    final rol = Rol.values.firstWhere(
      (item) => item.codigoBd == codigo,
      orElse: () => Rol.cliente,
    );
    return Usuario(
      nombres: data['nombres']?.toString() ?? '',
      apellidoPaterno: data['apellido_paterno']?.toString(),
      apellidoMaterno: data['apellido_materno']?.toString(),
      celular: data['celular']?.toString() ?? celular,
      correo: data['correo']?.toString(),
      fechaNacimiento: data['fecha_nacimiento'] == null
          ? null
          : DateTime.tryParse(data['fecha_nacimiento'].toString()),
      letraGrande: data['letra_grande'] == true,
      sonido: data['sonido'] != false,
      vibracion: data['vibracion'] != false,
      rol: rol,
      puestoId: (data['puesto_id'] as num?)?.toInt(),
      mercadoId: (data['mercado_id'] as num?)?.toInt(),
    );
  }

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
        fechaNacimiento: usuarioJson['fecha_nacimiento'] == null
            ? null
            : DateTime.tryParse(usuarioJson['fecha_nacimiento'].toString()),
        letraGrande: usuarioJson['letra_grande'] == true,
        sonido: usuarioJson['sonido'] != false,
        vibracion: usuarioJson['vibracion'] != false,
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
