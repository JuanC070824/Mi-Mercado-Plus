import '../models/direccion.dart';
import '../models/rol.dart';
import '../models/usuario.dart';

// PARA EL MVP, simula al backend, esto al 06/10 por ahora


class ResultadoAuth {
  const ResultadoAuth.ok(this.usuario)
      : exito = true,
        mensaje = '';
  const ResultadoAuth.error(this.mensaje)
      : exito = false,
        usuario = null;

  final bool exito;
  final String mensaje;
  final Usuario? usuario;
}

abstract class AuthRepository {
  Future<ResultadoAuth> iniciarSesion({
    required String celular,
    required String password,
    required Rol rol,
  });

  Future<ResultadoAuth> registrarCliente({
    required Usuario usuario,
    required String password,
    Direccion? direccion,
  });
}

class _Cuenta {
  _Cuenta({
    required this.usuario,
    required this.password,
    this.estado = 'activo',
    this.direccion,
  });
  final Usuario usuario;
  final String password;
  final String estado; // activo | suspendido | inactivo
  final Direccion? direccion;
}

/// Simula al backend. Los datos viven en memoria y se pierden al reiniciar.
class AuthRepositoryMock implements AuthRepository {
  AuthRepositoryMock._();
  static final AuthRepositoryMock instancia = AuthRepositoryMock._();

  final Map<String, _Cuenta> _porCelular = {
    '987654321': _Cuenta(
      usuario: const Usuario(
        nombres: 'María Esperanza',
        apellidoPaterno: 'Del Pilar',
        apellidoMaterno: 'López',
        celular: '987654321',
        correo: 'maria@correo.com',
        rol: Rol.cliente,
      ),
      password: 'Mercado123',
    ),
    '955555555': _Cuenta(
      usuario: const Usuario(
        nombres: 'Cuenta',
        apellidoPaterno: 'Suspendida',
        celular: '955555555',
        rol: Rol.cliente,
      ),
      password: 'Mercado123',
      estado: 'suspendido',
    ),
  };

  @override
  Future<ResultadoAuth> iniciarSesion({
    required String celular,
    required String password,
    required Rol rol,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    final c = _porCelular[celular];
    if (c == null || c.password != password) {
      return const ResultadoAuth.error(
        'Celular o contraseña incorrectos. Revísalos e inténtalo de nuevo.',
      );
    }
    if (c.estado != 'activo') {
      return ResultadoAuth.error(
        'Tu cuenta no está activa (${c.estado}). Escribe a Soporte para resolverlo.',
      );
    }
    if (c.usuario.rol != rol) {
      return ResultadoAuth.error(
        'Este celular está registrado como ${c.usuario.rol.etiqueta}. '
        'Vuelve atrás y elige ese perfil.',
      );
    }
    return ResultadoAuth.ok(c.usuario);
  }

  @override
  Future<ResultadoAuth> registrarCliente({
    required Usuario usuario,
    required String password,
    Direccion? direccion,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_porCelular.containsKey(usuario.celular)) {
      return const ResultadoAuth.error(
        'Este celular ya tiene una cuenta. Inicia sesión.',
      );
    }
    final correo = usuario.correo?.toLowerCase();
    if (correo != null &&
        _porCelular.values.any((c) => c.usuario.correo?.toLowerCase() == correo)) {
      return const ResultadoAuth.error(
        'Este correo ya está registrado. Usa otro o inicia sesión.',
      );
    }
    _porCelular[usuario.celular] =
        _Cuenta(usuario: usuario, password: password, direccion: direccion);
    return ResultadoAuth.ok(usuario);
  }
}