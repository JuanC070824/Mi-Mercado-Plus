class Direccion {
  const Direccion({
    this.etiqueta = 'Casa',
    required this.direccion,
    this.referencia,
    this.latitud,
    this.longitud,
    this.principal = true,
  });

  final String etiqueta;
  final String direccion;
  final String? referencia;
  final double? latitud;
  final double? longitud;
  final bool principal;
}