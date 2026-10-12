/// repartidor_mercados.movilidad
enum Movilidad {
  aPie('A pie'),
  carretilla('Carretilla'),
  bicicleta('Bicicleta'),
  moto('Moto'),
  mototaxi('Mototaxi');

  const Movilidad(this.etiqueta);
  final String etiqueta;
}

/// Repartidor (estibador) autorizado en un mercado.
class Repartidor {
  const Repartidor({
    required this.nombre,
    required this.celular,
    required this.mercadoId,
    required this.movilidad,
    this.placa,
    required this.calificacion,
  });

  final String nombre;
  final String celular;
  final int mercadoId;
  final Movilidad movilidad;
  final String? placa;
  final double calificacion;

  /// "Mototaxi · MT-4521"
  String get movilidadTexto =>
      placa == null ? movilidad.etiqueta : '${movilidad.etiqueta} · $placa';
}
