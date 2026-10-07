import 'dart:math';
import '../models/mercado.dart';
import '../models/puesto.dart';

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
    final lista = _puestos
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
    final lista = _puestos.where((p) {
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
}