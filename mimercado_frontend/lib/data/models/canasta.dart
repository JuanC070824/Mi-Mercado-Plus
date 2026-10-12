import 'cotizacion.dart';
import 'producto.dart';
import 'puesto.dart';

/// Un producto dentro de la canasta (carrito_items).
class ItemCanasta {
  const ItemCanasta({required this.producto, required this.cantidad});

  final Producto producto;
  final double cantidad; // kg/litros de 0.5 en 0.5; unidades y atados de 1 en 1

  /// Precio estimado: el casero confirma el final al pesar.
  double get subtotal => redondear2(cantidad * producto.precioUnitario);
}

/// Lo que el cliente lleva de UN puesto (carrito_puestos).
class GrupoPuesto {
  const GrupoPuesto({
    required this.puesto,
    required this.items,
    this.listaMandado,
  });

  final Puesto puesto; // completo: crearPedido necesita el Puesto, no solo el id
  final List<ItemCanasta> items;
  final String? listaMandado; // texto libre: "un atado de culantro y 3 ajíes"

  double get subtotal => redondear2(items.fold(0.0, (s, i) => s + i.subtotal));

  ItemCanasta? item(int productoId) {
    for (final i in items) {
      if (i.producto.id == productoId) return i;
    }
    return null;
  }

  GrupoPuesto copyWith({List<ItemCanasta>? items, String? listaMandado}) =>
      GrupoPuesto(
        puesto: puesto,
        items: items ?? this.items,
        listaMandado: listaMandado ?? this.listaMandado,
      );
}

/// La canasta del cliente: un grupo por puesto, todos del mismo mercado.
class Canasta {
  const Canasta({this.grupos = const []});

  /// Igual que PedidoRepositoryMock.costoEnvio.
  static const double costoEnvio = 5.00;

  final List<GrupoPuesto> grupos;

  bool get vacia => grupos.isEmpty;

  /// Mercado de la canasta (null si está vacía).
  int? get mercadoId => vacia ? null : grupos.first.puesto.mercadoId;

  /// Cuántos productos distintos lleva (para el globito del menú).
  int get cantidadProductos => grupos.fold(0, (s, g) => s + g.items.length);

  double get totalProductos =>
      redondear2(grupos.fold(0.0, (s, g) => s + g.subtotal));
  double get envio => vacia ? 0 : costoEnvio;
  double get totalEstimado => redondear2(totalProductos + envio);

  GrupoPuesto? grupo(int puestoId) {
    for (final g in grupos) {
      if (g.puesto.id == puestoId) return g;
    }
    return null;
  }

  /// Cantidad que ya lleva de un producto (0 si no está en la canasta).
  double cantidadDe(int productoId) {
    for (final g in grupos) {
      final i = g.item(productoId);
      if (i != null) return i.cantidad;
    }
    return 0;
  }
}
