import 'package:flutter/foundation.dart';

import '../models/canasta.dart';
import '../models/producto.dart';
import '../models/puesto.dart';

/// Error de la canasta con un mensaje listo para mostrar al usuario.
class CanastaException implements Exception {
  const CanastaException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

abstract class CanastaRepository {
  /// La canasta actual. La barra "Tu canasta · S/ X" y la tarjeta de Inicio
  /// la escuchan para actualizarse solas.
  ValueListenable<Canasta> get canasta;

  /// Suma un paso (0.5 kg, 1 atado…) del producto.
  /// Falla si es de otro mercado, si está agotado o si el puesto está cerrado.
  Future<Canasta> agregar(Puesto puesto, Producto producto);

  /// Resta un paso; si llega a 0 lo quita de la canasta.
  Future<Canasta> restar(Producto producto);

  /// Fija la cantidad exacta (se ajusta al paso de la unidad). 0 = quitar.
  Future<Canasta> cambiarCantidad(
    Puesto puesto,
    Producto producto,
    double cantidad,
  );

  Future<Canasta> quitar(int productoId);

  /// Lista de mandado de un puesto (C3b). Texto vacío = borrarla.
  Future<Canasta> guardarListaMandado(int puestoId, String texto);

  Future<Canasta> vaciar();
}

/// Simula al backend. Una sola canasta en memoria (la del usuario que entró).
class CanastaRepositoryMock implements CanastaRepository {
  CanastaRepositoryMock._();
  static final CanastaRepositoryMock instancia = CanastaRepositoryMock._();

  static const int maxListaMandado = 300;

  final ValueNotifier<Canasta> _canasta = ValueNotifier(const Canasta());

  @override
  ValueListenable<Canasta> get canasta => _canasta;

  @override
  Future<Canasta> agregar(Puesto puesto, Producto producto) => cambiarCantidad(
    puesto,
    producto,
    _canasta.value.cantidadDe(producto.id) + producto.unidad.paso,
  );

  @override
  Future<Canasta> restar(Producto producto) async {
    final actual = _canasta.value.cantidadDe(producto.id);
    if (actual == 0) return _canasta.value;
    final g = _grupoDeProducto(producto.id);
    return cambiarCantidad(g.puesto, producto, actual - producto.unidad.paso);
  }

  @override
  Future<Canasta> cambiarCantidad(
    Puesto puesto,
    Producto producto,
    double cantidad,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final c = _canasta.value;
    final nueva = _ajustarAlPaso(cantidad, producto.unidad);
    final anterior = c.cantidadDe(producto.id);

    // Solo se valida al aumentar: quitar siempre está permitido.
    if (nueva > anterior) {
      if (c.mercadoId != null && c.mercadoId != puesto.mercadoId) {
        throw const CanastaException(
          'Tu canasta tiene productos de otro mercado. '
          'Termina ese pedido o vacía tu canasta para comprar aquí.',
        );
      }
      if (!puesto.abierto) {
        throw CanastaException(
          '${puesto.nombre} está cerrado ahora. Prueba con otro puesto.',
        );
      }
      if (!producto.disponible) {
        throw CanastaException('${producto.nombre} está agotado por hoy.');
      }
    }

    final grupos = [...c.grupos];
    final i = grupos.indexWhere((g) => g.puesto.id == puesto.id);
    final grupo = i == -1
        ? GrupoPuesto(puesto: puesto, items: const [])
        : grupos[i];
    // Se respeta el orden en que el cliente agregó los productos.
    final yaEstaba = grupo.item(producto.id) != null;
    final items = [
      for (final it in grupo.items)
        if (it.producto.id != producto.id)
          it
        else if (nueva > 0)
          ItemCanasta(producto: producto, cantidad: nueva),
      if (!yaEstaba && nueva > 0)
        ItemCanasta(producto: producto, cantidad: nueva),
    ];

    if (items.isEmpty) {
      if (i != -1) grupos.removeAt(i); // el puesto sale de la canasta
    } else if (i == -1) {
      grupos.add(grupo.copyWith(items: items));
    } else {
      grupos[i] = grupo.copyWith(items: items);
    }
    return _publicar(Canasta(grupos: grupos));
  }

  @override
  Future<Canasta> quitar(int productoId) async {
    final c = _canasta.value;
    for (final g in c.grupos) {
      final it = g.item(productoId);
      if (it != null) return cambiarCantidad(g.puesto, it.producto, 0);
    }
    return c;
  }

  @override
  Future<Canasta> guardarListaMandado(int puestoId, String texto) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final limpio = texto.trim();
    if (limpio.length > maxListaMandado) {
      throw const CanastaException(
        'La lista de mandado puede tener hasta $maxListaMandado letras. '
        'Acórtala un poco.',
      );
    }
    final c = _canasta.value;
    final g = c.grupo(puestoId);
    if (g == null) {
      throw const CanastaException(
        'Primero agrega un producto de este puesto a tu canasta.',
      );
    }
    final actualizado = GrupoPuesto(
      puesto: g.puesto,
      items: g.items,
      listaMandado: limpio.isEmpty ? null : limpio,
    );
    return _publicar(
      Canasta(
        grupos: [
          for (final x in c.grupos) x.puesto.id == puestoId ? actualizado : x,
        ],
      ),
    );
  }

  @override
  Future<Canasta> vaciar() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _publicar(const Canasta());
  }

  // ---------------------------------------------------------------- Internos

  Canasta _publicar(Canasta c) {
    _canasta.value = c;
    return c;
  }

  GrupoPuesto _grupoDeProducto(int productoId) =>
      _canasta.value.grupos.firstWhere((g) => g.item(productoId) != null);

  /// 1.3 kg → 1.5 kg; 2.2 atados → 2 atados. Nunca negativo.
  static double _ajustarAlPaso(double cantidad, UnidadMedida unidad) {
    if (cantidad <= 0) return 0;
    final pasos = (cantidad / unidad.paso).round();
    return pasos * unidad.paso;
  }
}
