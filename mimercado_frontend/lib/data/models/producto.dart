// Contrato §2.1 (tarea M1 de Michael). Se adelanta aquí porque PedidoDetalle
// necesita UnidadMedida; si Michael sube su versión, se queda la suya.

/// kg y litro avanzan de 0.5; unidad y atado, de 1.
enum UnidadMedida {
  kg('kg', 0.5),
  unidad('und.', 1),
  atado('atado', 1),
  litro('L', 0.5);

  const UnidadMedida(this.simbolo, this.paso);
  final String simbolo;
  final double paso;
}

class Producto {
  const Producto({
    required this.id,
    required this.puestoId,
    required this.nombre,
    required this.unidad,
    required this.precioUnitario,
    this.disponible = true,
    this.imagen,
  });

  final int id;
  final int puestoId;
  final String nombre;
  final UnidadMedida unidad;
  final double precioUnitario;
  final bool disponible;
  final String? imagen;

  /// Para editar precio o disponibilidad desde el catálogo del casero (V7).
  Producto copyWith({
    String? nombre,
    UnidadMedida? unidad,
    double? precioUnitario,
    bool? disponible,
    String? imagen,
  }) => Producto(
    id: id,
    puestoId: puestoId,
    nombre: nombre ?? this.nombre,
    unidad: unidad ?? this.unidad,
    precioUnitario: precioUnitario ?? this.precioUnitario,
    disponible: disponible ?? this.disponible,
    imagen: imagen ?? this.imagen,
  );
}
