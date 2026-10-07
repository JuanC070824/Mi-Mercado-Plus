class Mercado {
  const Mercado({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.distrito,
    required this.latitud,
    required this.longitud,
  });

  final int id;
  final String nombre;
  final String direccion;
  final String? distrito;
  final double latitud;
  final double longitud;
}

/// Un mercado junto con su distancia al cliente (null si aún no sabemos dónde está).
class MercadoCercano {
  const MercadoCercano(this.mercado, [this.distanciaKm]);

  final Mercado mercado;
  final double? distanciaKm;

  String? get distanciaTexto {
    final d = distanciaKm;
    if (d == null) return null;
    if (d < 1) return 'a ${(d * 1000).round()} m';
    return 'a ${d.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}