/// Redondea a céntimos para que las sumas no arrastren decimales raros.
double redondear2(double x) => (x * 100).round() / 100;

enum EstadoCotizacion {
  borrador('Pesando…', 'borrador'),
  enviada('Precio final listo', 'enviada'),
  aceptada('Aceptado', 'aceptada'),
  reemplazada('Reemplazado', 'reemplazada');

  const EstadoCotizacion(this.etiqueta, this.codigoBd);
  final String etiqueta;
  final String codigoBd;
}

/// Lo que el casero pesó de un producto del pedido.
class CotizacionDetalle {
  const CotizacionDetalle({
    required this.pedidoDetalleId,
    required this.nombreFinal,
    required this.cantidadReal,
    required this.precioUnitario,
  });

  final int pedidoDetalleId;
  final String nombreFinal; // puede cambiar si el casero ofrece un reemplazo
  final double cantidadReal;
  final double precioUnitario;

  double get subtotal => redondear2(cantidadReal * precioUnitario);
}

/// Precio final de UN puesto. La comisión de la app se calcula, no se escribe.
class CotizacionPuesto {
  const CotizacionPuesto({
    required this.pedidoPuestoId,
    required this.detalles,
    this.nota,
    this.tasaComision = 0.05,
  });

  final int pedidoPuestoId;
  final List<CotizacionDetalle> detalles;
  final String? nota;
  final double tasaComision;

  /// Lo que paga el cliente por este puesto.
  double get bruto => redondear2(detalles.fold(0.0, (s, d) => s + d.subtotal));
  double get comision => redondear2(bruto * tasaComision);

  /// Lo que recibe el casero.
  double get neto => redondear2(bruto - comision);
}

class Cotizacion {
  const Cotizacion({
    required this.version,
    required this.estado,
    required this.costoEnvio,
    required this.puestos,
  });

  final int version;
  final EstadoCotizacion estado;
  final double costoEnvio;
  final List<CotizacionPuesto> puestos;

  double get totalProductos =>
      redondear2(puestos.fold(0.0, (s, p) => s + p.bruto));
  double get totalCliente => redondear2(totalProductos + costoEnvio);

  CotizacionPuesto? dePuesto(int pedidoPuestoId) {
    for (final p in puestos) {
      if (p.pedidoPuestoId == pedidoPuestoId) return p;
    }
    return null;
  }

  Cotizacion copyWith({EstadoCotizacion? estado, List<CotizacionPuesto>? puestos}) =>
      Cotizacion(
        version: version,
        estado: estado ?? this.estado,
        costoEnvio: costoEnvio,
        puestos: puestos ?? this.puestos,
      );
}
