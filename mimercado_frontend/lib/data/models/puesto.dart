enum CategoriaPuesto {
  verduras('Verduras y frutas', 'assets/images/cat_verduras.png'),
  carnes('Carnes y aves', 'assets/images/cat_carnes.png'),
  abarrotes('Abarrotes', 'assets/images/cat_abarrotes.png'),
  pescados('Pescados y mariscos', 'assets/images/cat_pescados.png');

  const CategoriaPuesto(this.nombre, this.imagen);
  final String nombre;
  final String imagen;
}

class Puesto {
  const Puesto({
    required this.id,
    required this.mercadoId,
    required this.nombre,
    required this.casero,
    required this.categoria,
    required this.calificacion,
    required this.resenas,
    this.abierto = true,
  });

  final int id;
  final int mercadoId;
  final String nombre;
  final String casero;
  final CategoriaPuesto categoria;
  final double calificacion; // promedio de resenas_puesto.estrellas
  final int resenas;
  final bool abierto; // puestos.abierto
}
