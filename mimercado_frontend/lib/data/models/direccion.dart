class Direccion {
  const Direccion({
    this.id,
    this.etiqueta = 'Casa',
    required this.direccion,
    this.referencia,
    this.latitud,
    this.longitud,
    this.principal = true,
  });

  final int? id;

  final String etiqueta;
  final String direccion;
  final String? referencia;
  final double? latitud;
  final double? longitud;
  final bool principal;
}
