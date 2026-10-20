//Se usa para simular los pagos en línea

/// Resultado de un pago. Nunca guarda el código de aprobación de Yape.
class ResultadoPago {
  const ResultadoPago.aprobado() : aprobado = true, mensaje = '';
  const ResultadoPago.rechazado(this.mensaje) : aprobado = false;

  final bool aprobado;
  final String mensaje;
}

abstract class PagoRepository {
  /// Cobra con Yape (en producción: Culqi en modo sandbox, desde el backend).
  Future<ResultadoPago> pagarConYape({
    required String celular,
    required String codigo,
    required double monto,
  });

  /// "El código debe tener 6 números" o null si está bien (para el formulario).
  String? validarCodigoYape(String? codigo);
}

/// Simula el pago. `000000` devuelve "rechazado" para probar el error.
class PagoRepositoryMock implements PagoRepository {
  PagoRepositoryMock._();
  static final PagoRepositoryMock instancia = PagoRepositoryMock._();

  static const codigoDePrueba = '000000';

  @override
  String? validarCodigoYape(String? codigo) {
    final c = (codigo ?? '').trim();
    if (c.isEmpty) return 'Escribe el código de aprobación de Yape.';
    if (!RegExp(r'^\d{6}$').hasMatch(c))
      return 'El código debe tener 6 números.';
    return null;
  }

  @override
  Future<ResultadoPago> pagarConYape({
    required String celular,
    required String codigo,
    required double monto,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!RegExp(r'^9\d{8}$').hasMatch(celular)) {
      return const ResultadoPago.rechazado(
        'El celular de Yape debe tener 9 números y empezar con 9.',
      );
    }
    final errorCodigo = validarCodigoYape(codigo);
    if (errorCodigo != null) return ResultadoPago.rechazado(errorCodigo);
    if (codigo == codigoDePrueba) {
      return const ResultadoPago.rechazado(
        'El código no es válido o ya venció. Genera uno nuevo en Yape.',
      );
    }
    if (monto <= 0) {
      return const ResultadoPago.rechazado('No hay nada que cobrar.');
    }
    return const ResultadoPago.aprobado();
  }
}
