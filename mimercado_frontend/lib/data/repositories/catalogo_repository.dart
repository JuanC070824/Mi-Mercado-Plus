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
    ),
    Mercado(
      id: 5,
      nombre: 'Mercado Venezuela',
      direccion: 'Av. Venezuela 3176, Lima 15081',
      distrito: 'Cercado de Lima',
      latitud: -12.058950,
      longitud: -77.076050,
    ),  
    Mercado(
      id: 6,
      nombre: 'Mercado Cooperativa Elio',
      direccion: 'Roberto Thorndike Galup 1423, Lima 15081',
      distrito: 'Cercado de Lima',
      latitud: -12.055000,
      longitud: -77.068611,
    ),
    Mercado(
      id: 7,
      nombre: 'Mercado Colonial',
      direccion: 'Av. Óscar R. Benavides (Ex Colonial) 5405',
      distrito: 'Cercado de Lima',
      latitud: -12.051939,
      longitud: -77.082725,
    ),
    Mercado(
      id: 8,
      nombre: 'Mercado Unidad Vecinal 3',
      direccion: 'Av. Unidad Vecinal 3',
      distrito: 'Cercado de Lima',
      latitud: -12.051110,
      longitud: -77.078420,
    ),
    Mercado(
      id: 9,
      nombre: 'Mercado Pando',
      direccion: 'Calle José de la Riva Agüero 380, Urb. Pando',
      distrito: 'San Miguel',
      latitud: -12.061730,
      longitud: -77.086430,
    ),   
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
    Puesto(id: 14, mercadoId: 4, nombre: 'Verdulería Choque', casero: 'Justiniano Choque', categoria: CategoriaPuesto.verduras, calificacion: 4.5, resenas: 12),
    Puesto(id: 15, mercadoId: 4, nombre: 'Abarrotes El Chanchamayano', casero: 'Clara Quispe', categoria: CategoriaPuesto.abarrotes, calificacion: 4.7, resenas: 34),
    Puesto(id: 16, mercadoId: 4, nombre: 'Carnes El Torito de Pucará', casero: 'Esteban Ccoyllo', categoria: CategoriaPuesto.carnes, calificacion: 4.2, resenas: 19),
    Puesto(id: 17, mercadoId: 4, nombre: 'Pescados y Mariscos Sarita', casero: 'Sara Tintaya', categoria: CategoriaPuesto.pescados, calificacion: 4.8, resenas: 8),
    Puesto(id: 18, mercadoId: 5, nombre: 'Frutas y Verduras Doña Bertha', casero: 'Bertha Mendoza', categoria: CategoriaPuesto.verduras, calificacion: 4.9, resenas: 15),
    Puesto(id: 19, mercadoId: 5, nombre: 'Distribuidora San Marquitos', casero: 'Carlos Alva', categoria: CategoriaPuesto.abarrotes, calificacion: 4.3, resenas: 27),
    Puesto(id: 20, mercadoId: 5, nombre: 'Carnicería Fiel y Sabor', casero: 'Humberto Solís', categoria: CategoriaPuesto.carnes, calificacion: 3.8, resenas: 4, abierto: false),
    Puesto(id: 21, mercadoId: 5, nombre: 'Terminal Pesquero El Puerto', casero: 'Marina Espinoza', categoria: CategoriaPuesto.pescados, calificacion: 4.6, resenas: 11),
    Puesto(id: 22, mercadoId: 6, nombre: 'Abarrotes El Sol del Rímac', casero: 'Félix Tello', categoria: CategoriaPuesto.abarrotes, calificacion: 4.4, resenas: 16),
    Puesto(id: 23, mercadoId: 6, nombre: 'Verduras De Mi Tierra', casero: 'Teodora Huamaní', categoria: CategoriaPuesto.verduras, calificacion: 4.7, resenas: 22),
    Puesto(id: 24, mercadoId: 6, nombre: 'Cortes Finos Elio', casero: 'Ricardo Paredes', categoria: CategoriaPuesto.carnes, calificacion: 4.1, resenas: 9),
    Puesto(id: 25, mercadoId: 7, nombre: 'El Rey de los Mariscos', casero: 'Enrique Cáceda', categoria: CategoriaPuesto.pescados, calificacion: 4.9, resenas: 41),
    Puesto(id: 26, mercadoId: 7, nombre: 'Verdulería La Chacra a tu Mesa', casero: 'Yolanda Flores', categoria: CategoriaPuesto.verduras, calificacion: 4.3, resenas: 13),
    Puesto(id: 27, mercadoId: 7, nombre: 'Bodega Colonial Express', casero: 'Jorge Ortiz', categoria: CategoriaPuesto.abarrotes, calificacion: 4.5, resenas: 50),
    Puesto(id: 28, mercadoId: 7, nombre: 'Avícola San Fernando del Norte', casero: 'Lucía Benavides', categoria: CategoriaPuesto.carnes, calificacion: 4.0, resenas: 7),
    Puesto(id: 29, mercadoId: 8, nombre: 'Abarrotes Don Pepe', casero: 'José Gálvez', categoria: CategoriaPuesto.abarrotes, calificacion: 4.2, resenas: 18),
    Puesto(id: 30, mercadoId: 8, nombre: 'El Caserito de la UV3', casero: 'Nicanor Rojas', categoria: CategoriaPuesto.verduras, calificacion: 4.6, resenas: 29),
    Puesto(id: 31, mercadoId: 8, nombre: 'Pescadería San Pedro', casero: 'Pedro Marín', categoria: CategoriaPuesto.pescados, calificacion: 4.4, resenas: 5, abierto: false),
    Puesto(id: 32, mercadoId: 9, nombre: 'Frutería San Miguelito', casero: 'Milagros Palomino', categoria: CategoriaPuesto.verduras, calificacion: 4.8, resenas: 33),
    Puesto(id: 33, mercadoId: 9, nombre: 'Carnicería El Buen Corte', casero: 'Alfonso Zavala', categoria: CategoriaPuesto.carnes, calificacion: 4.5, resenas: 24),
    Puesto(id: 34, mercadoId: 9, nombre: 'Minimarket Pando Gourmet', casero: 'Elena Barrientos', categoria: CategoriaPuesto.abarrotes, calificacion: 4.1, resenas: 12),
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
          conUbicacion && m.latitud != null && m.longitud != null
              ? _km(latitud, longitud, m.latitud!, m.longitud!)
              : null,
        ),
    ];
    if (conUbicacion) {
      lista.sort((a, b) {
        final distanciaA = a.distanciaKm;
        final distanciaB = b.distanciaKm;
        if (distanciaA == null) return distanciaB == null ? 0 : 1;
        if (distanciaB == null) return -1;
        return distanciaA.compareTo(distanciaB);
      });
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

     // 9 · Pescadería Neptuno (Mercado 2)
    const Producto(id: 901, puestoId: 9, nombre: 'Trucha', unidad: UnidadMedida.kg, precioUnitario: 18.00),
    const Producto(id: 902, puestoId: 9, nombre: 'Liza', unidad: UnidadMedida.kg, precioUnitario: 12.00),

    // 10 · Abarrotes Central (Mercado 2)
    const Producto(id: 1001, puestoId: 10, nombre: 'Azúcar rubia', unidad: UnidadMedida.kg, precioUnitario: 3.80),
    const Producto(id: 1002, puestoId: 10, nombre: 'Leche evaporada', unidad: UnidadMedida.unidad, precioUnitario: 4.20),

    // 11 · Verduras Doña Pilar (Mercado 3)
    const Producto(id: 1101, puestoId: 11, nombre: 'Brócoli', unidad: UnidadMedida.kg, precioUnitario: 5.00),
    const Producto(id: 1102, puestoId: 11, nombre: 'Lechuga orgánica', unidad: UnidadMedida.unidad, precioUnitario: 2.50),

    // 12 · Mariscos del Pacífico (Mercado 3)
    const Producto(id: 1201, puestoId: 12, nombre: 'Mixtura de mariscos', unidad: UnidadMedida.kg, precioUnitario: 25.00),
    const Producto(id: 1202, puestoId: 12, nombre: 'Choros', unidad: UnidadMedida.kg, precioUnitario: 6.00),

    // 13 · Carnicería Magdalena (Mercado 3)
    const Producto(id: 1301, puestoId: 13, nombre: 'Chuleta de cerdo', unidad: UnidadMedida.kg, precioUnitario: 16.50),
    const Producto(id: 1302, puestoId: 13, nombre: 'Panceta', unidad: UnidadMedida.kg, precioUnitario: 22.00),

    // 14 · Verdulería Choque (Mercado Modelo de Vitarte)
    const Producto(id: 1401, puestoId: 14, nombre: 'Camote amarillo', unidad: UnidadMedida.kg, precioUnitario: 2.50),
    const Producto(id: 1402, puestoId: 14, nombre: 'Choclo serrano', unidad: UnidadMedida.unidad, precioUnitario: 1.50),

    // 15 · Abarrotes El Chanchamayano (Mercado Modelo de Vitarte)
    const Producto(id: 1501, puestoId: 15, nombre: 'Café molido pasita', unidad: UnidadMedida.unidad, precioUnitario: 15.00),
    const Producto(id: 1502, puestoId: 15, nombre: 'Menestra lenteja', unidad: UnidadMedida.kg, precioUnitario: 6.50),

    // 16 · Carnes El Torito de Pucará (Mercado Modelo de Vitarte)
    const Producto(id: 1601, puestoId: 16, nombre: 'Lomo de res', unidad: UnidadMedida.kg, precioUnitario: 34.00),
    const Producto(id: 1602, puestoId: 16, nombre: 'Hígado de res', unidad: UnidadMedida.kg, precioUnitario: 14.00),

    // 17 · Pescados y Mariscos Sarita (Mercado Modelo de Vitarte)
    const Producto(id: 1701, puestoId: 17, nombre: 'Caballa', unidad: UnidadMedida.kg, precioUnitario: 8.00),
    const Producto(id: 1702, puestoId: 17, nombre: 'Calamar entero', unidad: UnidadMedida.kg, precioUnitario: 24.00),

    // 18 · Frutas y Verduras Doña Bertha (Mercado Venezuela)
    const Producto(id: 1801, puestoId: 18, nombre: 'Maracuyá', unidad: UnidadMedida.kg, precioUnitario: 4.50),
    const Producto(id: 1802, puestoId: 18, nombre: 'Manzana Israel', unidad: UnidadMedida.kg, precioUnitario: 5.50),

    // 19 · Distribuidora San Marquitos (Mercado Venezuela)
    const Producto(id: 1901, puestoId: 19, nombre: 'Fideos spaghetti', unidad: UnidadMedida.kg, precioUnitario: 5.00),
    const Producto(id: 1902, puestoId: 19, nombre: 'Atún en conserva', unidad: UnidadMedida.unidad, precioUnitario: 4.80),

    // 20 · Carnicería Fiel y Sabor (Mercado Venezuela - Cerrado)
    const Producto(id: 2001, puestoId: 20, nombre: 'Malaya de res', unidad: UnidadMedida.kg, precioUnitario: 21.00),

    // 21 · Terminal Pesquero El Puerto (Mercado Venezuela)
    const Producto(id: 2101, puestoId: 21, nombre: 'Corvina', unidad: UnidadMedida.kg, precioUnitario: 45.00),
    const Producto(id: 2102, puestoId: 21, nombre: 'Filete de perico', unidad: UnidadMedida.kg, precioUnitario: 22.00),

    // 22 · Abarrotes El Sol del Rímac (Mercado Cooperativa Elio)
    const Producto(id: 2201, puestoId: 22, nombre: 'Aceite de oliva', unidad: UnidadMedida.litro, precioUnitario: 32.00),
    const Producto(id: 2202, puestoId: 22, nombre: 'Sal yodada', unidad: UnidadMedida.kg, precioUnitario: 1.80),

    // 23 · Verduras De Mi Tierra (Mercado Cooperativa Elio)
    const Producto(id: 2301, puestoId: 23, nombre: 'Espinaca', unidad: UnidadMedida.atado, precioUnitario: 2.00),
    const Producto(id: 2302, puestoId: 23, nombre: 'Huacatay', unidad: UnidadMedida.atado, precioUnitario: 1.00),

    // 24 · Cortes Finos Elio (Mercado Cooperativa Elio)
    const Producto(id: 2401, puestoId: 24, nombre: 'Asado de tira', unidad: UnidadMedida.kg, precioUnitario: 29.50),

    // 25 · El Rey de los Mariscos (Mercado Colonial)
    const Producto(id: 2501, puestoId: 25, nombre: 'Pulpo fresco', unidad: UnidadMedida.kg, precioUnitario: 38.00),
    const Producto(id: 2502, puestoId: 25, nombre: 'Langostinos pelados', unidad: UnidadMedida.kg, precioUnitario: 32.00),

    // 26 · Verdulería La Chacra a tu Mesa (Mercado Colonial)
    const Producto(id: 2601, puestoId: 26, nombre: 'Espinaca fresca', unidad: UnidadMedida.atado, precioUnitario: 1.80),
    const Producto(id: 2602, puestoId: 26, nombre: 'Ajo molido puro', unidad: UnidadMedida.kg, precioUnitario: 14.00),

    // 27 · Bodega Colonial Express (Mercado Colonial)
    const Producto(id: 2701, puestoId: 27, nombre: 'Frugos litro', unidad: UnidadMedida.litro, precioUnitario: 5.50),
    const Producto(id: 2702, puestoId: 27, nombre: 'Arroz integral', unidad: UnidadMedida.kg, precioUnitario: 6.20),

    // 28 · Avícola San Fernando del Norte (Mercado Colonial)
    const Producto(id: 2801, puestoId: 28, nombre: 'Pechuga de pollo', unidad: UnidadMedida.kg, precioUnitario: 16.00),

    // 29 · Abarrotes Don Pepe (Mercado UV3)
    const Producto(id: 2901, puestoId: 29, nombre: 'Detergente bolsa', unidad: UnidadMedida.unidad, precioUnitario: 8.50),
    const Producto(id: 2902, puestoId: 29, nombre: 'Vinagre blanco', unidad: UnidadMedida.litro, precioUnitario: 3.50),

    // 30 · El Caserito de la UV3 (Mercado UV3)
    const Producto(id: 3001, puestoId: 30, nombre: 'Yuca amarilla', unidad: UnidadMedida.kg, precioUnitario: 3.00),
    const Producto(id: 3002, puestoId: 30, nombre: 'Ají amarillo', unidad: UnidadMedida.kg, precioUnitario: 7.00),

    // 31 · Pescadería San Pedro (Mercado UV3 - Cerrado)
    const Producto(id: 3101, puestoId: 31, nombre: 'Cabrilla', unidad: UnidadMedida.kg, precioUnitario: 26.00, disponible: false),

    // 32 · Frutería San Miguelito (Mercado Pando)
    const Producto(id: 3201, puestoId: 32, nombre: 'Fresa San Juan', unidad: UnidadMedida.kg, precioUnitario: 7.50),
    const Producto(id: 3202, puestoId: 32, nombre: 'Papaya selva', unidad: UnidadMedida.kg, precioUnitario: 4.00),

    // 33 · Carnicería El Buen Corte (Mercado Pando)
    const Producto(id: 3301, puestoId: 33, nombre: 'Pata de res', unidad: UnidadMedida.kg, precioUnitario: 9.00),
    const Producto(id: 3302, puestoId: 33, nombre: 'Carne para guiso', unidad: UnidadMedida.kg, precioUnitario: 24.00),

    // 34 · Minimarket Pando Gourmet (Mercado Pando)
    const Producto(id: 3401, puestoId: 34, nombre: 'Queso fresco andino', unidad: UnidadMedida.kg, precioUnitario: 26.00),
    const Producto(id: 3402, puestoId: 34, nombre: 'Mantequilla con sal', unidad: UnidadMedida.unidad, precioUnitario: 5.20),

  
  
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
