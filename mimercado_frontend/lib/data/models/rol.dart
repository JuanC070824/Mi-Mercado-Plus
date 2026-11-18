enum Rol {
  cliente('Cliente', 'comprador'),
  repartidor('Repartidor', 'repartidor'),
  comerciante('Comerciante', 'vendedor'),

  /// Responsable del mercado: autoriza repartidores y gestiona mercados (RF-05).
  administrador('Administrador', 'administrador');

  /// Los tres perfiles que se eligen en la bienvenida.
  static const publicos = [cliente, repartidor, comerciante];

  const Rol(this.etiqueta, this.codigoBd);
  final String etiqueta;

  /// Coincide con roles.codigo en la base de datos.
  final String codigoBd;
}
