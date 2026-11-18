import 'package:mimercado_frontend/core/i18n/idioma.dart';

class Mercado {
  const Mercado({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.distrito,
    this.latitud,
    this.longitud,
  });

  final int id;
  final String nombre;
  final String direccion;
  final String? distrito;
  final double? latitud;
  final double? longitud;
}

/// Un mercado junto con su distancia al cliente (null si aún no sabemos dónde está).
class MercadoCercano {
  const MercadoCercano(this.mercado, [this.distanciaKm]);

  final Mercado mercado;
  final double? distanciaKm;

  String? get distanciaTexto {
    final d = distanciaKm;
    if (d == null) return null;
    if (d < 1) return tr('a {0} m', [(d * 1000).round()]);
    return tr('a {0} km', [d.toStringAsFixed(1).replaceAll('.', ',')]);
  }
}
