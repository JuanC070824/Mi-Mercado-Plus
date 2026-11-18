enum Rol {
  cliente('Cliente', 'comprador'),
  repartidor('Repartidor', 'repartidor'),
  comerciante('Comerciante', 'vendedor');

  const Rol(this.etiqueta, this.codigoBd);
  final String etiqueta;

  /// Coincide con roles.codigo en la base de datos.
  final String codigoBd;
}
