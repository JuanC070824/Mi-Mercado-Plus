enum Rol {
  cliente('Cliente'),
  repartidor('Repartidor'),     // = Estibador en el documento
  comerciante('Comerciante');   // = Vendedor/Casero en el documento

  const Rol(this.etiqueta);
  final String etiqueta;
}