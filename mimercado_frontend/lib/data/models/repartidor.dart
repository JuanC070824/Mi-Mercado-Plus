/// repartidor_mercados.movilidad
enum Movilidad {
  aPie('Estibador a pie'),
  carretilla('Carretilla'),
  bicicleta('Bicicleta'),
  moto('Moto'),
  mototaxi('Mototaxi'),
  otro('Otra movilidad');

  const Movilidad(this.etiqueta);
  final String etiqueta;
  String get codigo => this == Movilidad.aPie ? 'a_pie' : name;
  static Movilidad desdeCodigo(String? valor) =>
      values.firstWhere((m) => m.codigo == valor, orElse: () => Movilidad.otro);
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
