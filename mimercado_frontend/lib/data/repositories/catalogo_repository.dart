import 'dart:math';
import '../models/mercado.dart';
import '../models/producto.dart';
import '../models/puesto.dart';

/// Error de catálogo con un mensaje listo para mostrar al usuario.
class CatalogoException implements Exception {
  const CatalogoException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

abstract class CatalogoRepository {
  /// Mercados activos. Con ubicación, ordenados del más cercano al más lejano.
  Future<List<MercadoCercano>> mercados({double? latitud, double? longitud});

  /// Puestos mejor calificados. Sin [mercadoId], de todos los mercados.
  Future<List<Puesto>> masQueridos({int? mercadoId, int limite = 5});

  /// Búsqueda dentro de UN mercado, por rubro y/o texto.
  Future<List<Puesto>> buscar({
    required int mercadoId,
    CategoriaPuesto? categoria,
    String texto = '',
  });

  /// Un puesto por su id (null si no existe).
  Future<Puesto?> puesto(int id);

  /// Productos de un puesto: primero los disponibles, luego los agotados.
  Future<List<Producto>> productosDePuesto(int puestoId);

  /// Cambia precio o disponibilidad de un producto (catálogo del casero, V7).
  Future<void> actualizarProducto(Producto producto);

  /// Interruptor "Puesto abierto / cerrado" del casero (V1).
  Future<Puesto> cambiarAbierto(int puestoId, bool abierto);
}

/// Datos de prueba. Las coordenadas son aproximadas.
class CatalogoRepositoryMock implements CatalogoRepository {
  static const _mercados = [
    Mercado(
      id: 1,
      nombre: 'Mercado N° 1 de Surquillo',
      direccion: 'Surquillo, Lima',
      distrito: 'Surquillo',
      latitud: -12.1130,
      longitud: -77.0200,
    ),
    Mercado(
      id: 2,
      nombre: 'Mercado Real Plaza APROMEC',
      direccion: 'Av Nicolás Ayllón',
      distrito: 'Ate',
      latitud: -12.0262673,
      longitud: -76.9224803,
    ),
    Mercado(
      id: 3,
      nombre: 'Plaza Vitarte',
      direccion: 'Av Nicolás Ayllón',
      distrito: 'Ate',
      latitud: -12.0257197,
      longitud: -76.9220639,
    ),
    Mercado(
      id: 4,
      nombre: 'Mercado Modelo de Vitarte',
      direccion: 'Av Nicolás Ayllón',
      distrito: 'Ate',
      latitud: -12.0256149,
      longitud: -76.9202483,
    )
  ];

  static const _puestos = [
    Puesto(id: 1, mercadoId: 1, nombre: 'Doña Rosa Verdulería', casero: 'Rosa Quispe', categoria: CategoriaPuesto.verduras, calificacion: 4.9, resenas: 5),
    Puesto(id: 2, mercadoId: 1, nombre: 'Mariscos Enrique', casero: 'Samuel Enrique', categoria: CategoriaPuesto.pescados, calificacion: 4.6, resenas: 9),
    Puesto(id: 3, mercadoId: 1, nombre: 'Carnicería Huancayo', casero: 'Julio Vega', categoria: CategoriaPuesto.carnes, calificacion: 3.9, resenas: 5),
    Puesto(id: 4, mercadoId: 1, nombre: 'Hermanos Sánchez', casero: 'Joel Sánchez', categoria: CategoriaPuesto.verduras, calificacion: 3.7, resenas: 6),
    Puesto(id: 5, mercadoId: 1, nombre: 'Abarrotes Doña Carmen', casero: 'Carmen Flores', categoria: CategoriaPuesto.abarrotes, calificacion: 4.8, resenas: 21),
    Puesto(id: 6, mercadoId: 1, nombre: 'Granja Don Lucho', casero: 'Luis Ramos', categoria: CategoriaPuesto.carnes, calificacion: 4.4, resenas: 14, abierto: false),
    Puesto(id: 7, mercadoId: 2, nombre: 'Frutas Mary', casero: 'Mary Condori', categoria: CategoriaPuesto.verduras, calificacion: 4.7, resenas: 18),
    Puesto(id: 8, mercadoId: 2, nombre: 'Carnes El Cuzqueño', casero: 'Hugo Mamani', categoria: CategoriaPuesto.carnes, calificacion: 4.5, resenas: 11),
    Puesto(id: 9, mercadoId: 2, nombre: 'Pescadería Neptuno', casero: 'Elías Ríos', categoria: CategoriaPuesto.pescados, calificacion: 4.3, resenas: 7),
    Puesto(id: 10, mercadoId: 2, nombre: 'Abarrotes Central', casero: 'Teresa Huamán', categoria: CategoriaPuesto.abarrotes, calificacion: 4.1, resenas: 9),
    Puesto(id: 11, mercadoId: 3, nombre: 'Verduras Doña Pilar', casero: 'Pilar Soto', categoria: CategoriaPuesto.verduras, calificacion: 4.6, resenas: 8),
    Puesto(id: 12, mercadoId: 3, nombre: 'Mariscos del Pacífico', casero: 'Walter Vega', categoria: CategoriaPuesto.pescados, calificacion: 4.8, resenas: 16),
    Puesto(id: 13, mercadoId: 3, nombre: 'Carnicería Magdalena', casero: 'Raúl Paredes', categoria: CategoriaPuesto.carnes, calificacion: 4.2, resenas: 6),
  ];

  /// Distancia entre dos puntos (fórmula de Haversine), en km.
  static double _km(double lat1, double lon1, double lat2, double lon2) {
    const radioTierra = 6371.0;
    double rad(double g) => g * pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) +
        cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
    return 2 * radioTierra * asin(sqrt(a));
  }

  /// Minúsculas y sin tildes, para que "pena" encuentre "Peña".
  static String _normalizar(String s) {
    const con = 'áéíóúüñ';
    const sin = 'aeiouun';
    var r = s.trim().toLowerCase();
    for (var i = 0; i < con.length; i++) {
      r = r.replaceAll(con[i], sin[i]);
    }
    return r;
  }

  static int _porCalificacion(Puesto a, Puesto b) {
    final c = b.calificacion.compareTo(a.calificacion);
    return c != 0 ? c : b.resenas.compareTo(a.resenas);
  }

  @override
  Future<List<MercadoCercano>> mercados({double? latitud, double? longitud}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final conUbicacion = latitud != null && longitud != null;
    final lista = [
      for (final m in _mercados)
        MercadoCercano(
          m,
          conUbicacion ? _km(latitud, longitud, m.latitud, m.longitud) : null,
        ),
    ];
    if (conUbicacion) {
      lista.sort((a, b) => a.distanciaKm!.compareTo(b.distanciaKm!));
    }
    return lista;
  }

  @override
  Future<List<Puesto>> masQueridos({int? mercadoId, int limite = 5}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lista = _vigentes
        .where((p) => mercadoId == null || p.mercadoId == mercadoId)
        .toList()
      ..sort(_porCalificacion);
    return lista.take(limite).toList();
  }

  @override
  Future<List<Puesto>> buscar({
    required int mercadoId,
    CategoriaPuesto? categoria,
    String texto = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = _normalizar(texto);
    final lista = _vigentes.where((p) {
      if (p.mercadoId != mercadoId) return false;
      if (categoria != null && p.categoria != categoria) return false;
      if (q.isEmpty) return true;
      return _normalizar(p.nombre).contains(q) || _normalizar(p.casero).contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.abierto != b.abierto) return a.abierto ? -1 : 1; // abiertos primero
        return _porCalificacion(a, b);
      });
    return lista;
  }

  // ---------------------------------------------------------------- Productos

  // IDs: número de puesto × 100 + correlativo (puesto 1 → 101, 102…).
  // Nombres y precios iguales a los de PedidoRepositoryMock: si cambias uno
  // aquí, cámbialo también allá para que el estimado de la canasta cuadre.
  // Es `static` y no `const` para que los cambios del casero (V7) los vean
  // todas las pantallas, aunque cada una cree su propio CatalogoRepositoryMock.
  static final List<Producto> _productos = [
    // 1 · Doña Rosa Verdulería
    const Producto(id: 101, puestoId: 1, nombre: 'Tomate', unidad: UnidadMedida.kg, precioUnitario: 4.00),
    const Producto(id: 102, puestoId: 1, nombre: 'Papa amarilla', unidad: UnidadMedida.kg, precioUnitario: 3.50),
    const Producto(id: 103, puestoId: 1, nombre: 'Limón', unidad: UnidadMedida.kg, precioUnitario: 8.00),
    const Producto(id: 104, puestoId: 1, nombre: 'Cebolla roja', unidad: UnidadMedida.kg, precioUnitario: 3.00),
    const Producto(id: 105, puestoId: 1, nombre: 'Culantro', unidad: UnidadMedida.atado, precioUnitario: 1.00),
    const Producto(id: 106, puestoId: 1, nombre: 'Zanahoria', unidad: UnidadMedida.kg, precioUnitario: 2.50, disponible: false),
    // 2 · Mariscos Enrique
    const Producto(id: 201, puestoId: 2, nombre: 'Bonito', unidad: UnidadMedida.kg, precioUnitario: 14.00),
    const Producto(id: 202, puestoId: 2, nombre: 'Jurel', unidad: UnidadMedida.kg, precioUnitario: 9.00),
    // 3 · Carnicería Huancayo
    const Producto(id: 301, puestoId: 3, nombre: 'Pollo entero', unidad: UnidadMedida.kg, precioUnitario: 10.00),
    const Producto(id: 302, puestoId: 3, nombre: 'Carne molida', unidad: UnidadMedida.kg, precioUnitario: 22.00),
    const Producto(id: 303, puestoId: 3, nombre: 'Bistec', unidad: UnidadMedida.kg, precioUnitario: 28.00),
    // 4 · Hermanos Sánchez
    const Producto(id: 401, puestoId: 4, nombre: 'Plátano de seda', unidad: UnidadMedida.kg, precioUnitario: 3.80),
    const Producto(id: 402, puestoId: 4, nombre: 'Palta fuerte', unidad: UnidadMedida.kg, precioUnitario: 8.50),
    // 5 · Abarrotes Doña Carmen
    const Producto(id: 501, puestoId: 5, nombre: 'Arroz extra', unidad: UnidadMedida.kg, precioUnitario: 4.20),
    const Producto(id: 502, puestoId: 5, nombre: 'Aceite vegetal', unidad: UnidadMedida.litro, precioUnitario: 9.50),
    const Producto(id: 503, puestoId: 5, nombre: 'Huevos', unidad: UnidadMedida.kg, precioUnitario: 7.50),
    // 6 · Granja Don Lucho (cerrado)
    const Producto(id: 601, puestoId: 6, nombre: 'Gallina', unidad: UnidadMedida.kg, precioUnitario: 12.00),
    // 7 · Frutas Mary (mercado 2)
    const Producto(id: 701, puestoId: 7, nombre: 'Mandarina', unidad: UnidadMedida.kg, precioUnitario: 4.50),
    const Producto(id: 702, puestoId: 7, nombre: 'Piña', unidad: UnidadMedida.unidad, precioUnitario: 6.00),
    // 8 · Carnes El Cuzqueño (mercado 2)
    const Producto(id: 801, puestoId: 8, nombre: 'Pollo entero', unidad: UnidadMedida.kg, precioUnitario: 10.50),
  ];

  @override
  Future<Puesto?> puesto(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final p in _vigentes) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<Producto>> productosDePuesto(int puestoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _productos.where((p) => p.puestoId == puestoId).toList()
      ..sort((a, b) {
        if (a.disponible != b.disponible) return a.disponible ? -1 : 1;
        return a.id.compareTo(b.id);
      });
  }

  @override
  Future<void> actualizarProducto(Producto producto) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _productos.indexWhere((p) => p.id == producto.id);
    if (i == -1) {
      throw const CatalogoException('No encontramos ese producto en tu catálogo.');
    }
    _productos[i] = producto;
  }

  // ------------------------------------------------------ Abierto / cerrado

  // Lo que el casero cambió hoy con su interruptor. Es `static` para que lo
  // vean todas las pantallas (cada una crea su propio CatalogoRepositoryMock).
  static final Map<int, bool> _abiertoHoy = {};

  /// Los puestos con el estado abierto/cerrado de hoy.
  static Iterable<Puesto> get _vigentes => _puestos.map(_conEstadoDeHoy);

  static Puesto _conEstadoDeHoy(Puesto p) {
    final abierto = _abiertoHoy[p.id];
    if (abierto == null || abierto == p.abierto) return p;
    return Puesto(
      id: p.id,
      mercadoId: p.mercadoId,
      nombre: p.nombre,
      casero: p.casero,
      categoria: p.categoria,
      calificacion: p.calificacion,
      resenas: p.resenas,
      abierto: abierto,
    );
  }

  @override
  Future<Puesto> cambiarAbierto(int puestoId, bool abierto) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final base = _puestos.where((p) => p.id == puestoId);
    if (base.isEmpty) {
      throw const CatalogoException('No encontramos tu puesto.');
    }
    _abiertoHoy[puestoId] = abierto;
    return _conEstadoDeHoy(base.first);
  }
}
