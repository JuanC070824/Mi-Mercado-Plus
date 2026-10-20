import '../models/direccion.dart';
import '../models/rol.dart';
import '../models/usuario.dart';

// PARA EL MVP, simula al backend, esto al 06/10 por ahora

class ResultadoAuth {
  const ResultadoAuth.ok(this.usuario) : exito = true, mensaje = '';
  const ResultadoAuth.error(this.mensaje) : exito = false, usuario = null;

  final bool exito;
  final String mensaje;
  final Usuario? usuario;
}

abstract class LoginRepository {
  Future<ResultadoAuth> iniciarSesion({
    required String celular,
    required String password,
    required Rol rol,
  });
}

abstract class RegistroRepository {
  Future<ResultadoAuth> registrarUsuario({
    required String dni,
    required String dniToken,
    required Usuario usuario,
    required String password,
    Direccion? direccion,
  });
}

abstract class AuthRepository implements LoginRepository, RegistroRepository {
  /// Dirección principal del comprador (null si aún no tiene).
  Future<Direccion?> direccionPrincipal(String celular);

  /// Actualiza celular, correo y (si se envía) la dirección principal.
  /// Valida que el celular y el correo no pertenezcan a otra cuenta.
  Future<ResultadoAuth> actualizarPerfil({
    required String celularActual,
    required String celular,
    String? correo,
    Direccion? direccion,
    String? passwordActual,
  });

  /// Guarda las preferencias de la cuenta (usuarios.sonido / usuarios.vibracion).
  Future<void> guardarPreferencias({
    required String celular,
    required bool sonido,
    required bool vibracion,
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
      // Dirección de demostración para probar el perfil.
      direccion: const Direccion(
        etiqueta: 'Casa',
        direccion: 'Av. Las Flores 245, San Isidro',
        referencia: 'Cerca a la juguería',
      ),
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
    // Casera de Doña Rosa Verdulería (puesto 1, mercado 1).
    '912345678': _Cuenta(
      usuario: const Usuario(
        nombres: 'Rosa',
        apellidoPaterno: 'Quispe',
        celular: '912345678',
        rol: Rol.comerciante,
        puestoId: 1,
        mercadoId: 1,
      ),
      password: 'Mercado123',
    ),
    // Repartidor autorizado del mercado 1 (mototaxi MT-4521).
    '923456789': _Cuenta(
      usuario: const Usuario(
        nombres: 'Ernesto',
        apellidoPaterno: 'Guevara',
        celular: '923456789',
        rol: Rol.repartidor,
        mercadoId: 1,
      ),
      password: 'Mercado123',
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
  Future<ResultadoAuth> registrarUsuario({
    required String dni,
    required String dniToken,
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
        _porCelular.values.any(
          (c) => c.usuario.correo?.toLowerCase() == correo,
        )) {
      return const ResultadoAuth.error(
        'Este correo ya está registrado. Usa otro o inicia sesión.',
      );
    }
    _porCelular[usuario.celular] = _Cuenta(
      usuario: usuario,
      password: password,
      direccion: direccion,
    );
    return ResultadoAuth.ok(usuario);
  }

  @override
  Future<Direccion?> direccionPrincipal(String celular) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _porCelular[celular]?.direccion;
  }

  @override
  Future<ResultadoAuth> actualizarPerfil({
    required String celularActual,
    required String celular,
    String? correo,
    Direccion? direccion,
    String? passwordActual,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final c = _porCelular[celularActual];
    if (c == null) {
      return const ResultadoAuth.error(
        'No encontramos tu cuenta. Vuelve a iniciar sesión.',
      );
    }
    if (celular != celularActual && _porCelular.containsKey(celular)) {
      return const ResultadoAuth.error(
        'Este celular ya está registrado en otra cuenta.',
      );
    }
    final nuevoCorreo = (correo == null || correo.trim().isEmpty)
        ? null
        : correo.trim();
    if (nuevoCorreo != null &&
        _porCelular.entries.any(
          (e) =>
              e.key != celularActual &&
              e.value.usuario.correo?.toLowerCase() ==
                  nuevoCorreo.toLowerCase(),
        )) {
      return const ResultadoAuth.error(
        'Este correo ya está registrado en otra cuenta.',
      );
    }
    final u = c.usuario;
    final nuevo = Usuario(
      nombres: u.nombres,
      apellidoPaterno: u.apellidoPaterno,
      apellidoMaterno: u.apellidoMaterno,
      celular: celular,
      correo: nuevoCorreo,
      fechaNacimiento: u.fechaNacimiento,
      letraGrande: u.letraGrande,
      sonido: u.sonido,
      vibracion: u.vibracion,
      rol: u.rol,
      puestoId: u.puestoId,
      mercadoId: u.mercadoId,
    );
    _porCelular.remove(celularActual);
    _porCelular[celular] = _Cuenta(
      usuario: nuevo,
      password: c.password,
      estado: c.estado,
      direccion: direccion ?? c.direccion,
    );
    return ResultadoAuth.ok(nuevo);
  }

  @override
  Future<void> guardarPreferencias({
    required String celular,
    required bool sonido,
    required bool vibracion,
  }) async {
    final c = _porCelular[celular];
    if (c == null) return;
    final u = c.usuario;
    _porCelular[celular] = _Cuenta(
      usuario: Usuario(
        nombres: u.nombres,
        apellidoPaterno: u.apellidoPaterno,
        apellidoMaterno: u.apellidoMaterno,
        celular: u.celular,
        correo: u.correo,
        fechaNacimiento: u.fechaNacimiento,
        letraGrande: u.letraGrande,
        sonido: sonido,
        vibracion: vibracion,
        rol: u.rol,
        puestoId: u.puestoId,
        mercadoId: u.mercadoId,
      ),
      password: c.password,
      estado: c.estado,
      direccion: c.direccion,
    );
  }
}
