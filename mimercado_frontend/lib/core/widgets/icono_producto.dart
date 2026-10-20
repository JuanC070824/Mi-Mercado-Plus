import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const iconosProducto = <String, ({String nombre, IconData icono, Color color})>{
  'icono:verdura': (
    nombre: 'Verdura',
    icono: Icons.eco_outlined,
    color: Color(0xFF2E9D65),
  ),
  'icono:fruta': (
    nombre: 'Fruta',
    icono: Icons.apple_outlined,
    color: Color(0xFFE05252),
  ),
  'icono:tuberculo': (
    nombre: 'Tubérculo',
    icono: Icons.grass,
    color: Color(0xFFB47738),
  ),
  'icono:abarrote': (
    nombre: 'Abarrote',
    icono: Icons.shopping_bag_outlined,
    color: AppColors.azul,
  ),
  'icono:carne': (
    nombre: 'Carne',
    icono: Icons.restaurant_outlined,
    color: Color(0xFFC84B5A),
  ),
  'icono:pescado': (
    nombre: 'Pescado',
    icono: Icons.set_meal_outlined,
    color: Color(0xFF10BCE3),
  ),
  'icono:lacteo': (
    nombre: 'Lácteo',
    icono: Icons.local_drink_outlined,
    color: Color(0xFF6E78C8),
  ),
  'icono:otro': (
    nombre: 'Otro',
    icono: Icons.inventory_2_outlined,
    color: Color(0xFF3DD6AF),
  ),
};

class IconoProducto extends StatelessWidget {
  const IconoProducto({super.key, this.valor, this.size = 58});
  final String? valor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dato = iconosProducto[valor] ?? iconosProducto['icono:otro']!;
    final esUrl =
        valor?.startsWith('http://') == true ||
        valor?.startsWith('https://') == true;
    return Semantics(
      image: true,
      label: 'Imagen referencial: ${dato.nombre}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: dato.color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: esUrl
            ? Image.network(
                valor!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(dato.icono, color: dato.color, size: size * .55),
              )
            : Icon(dato.icono, color: dato.color, size: size * .55),
      ),
    );
  }
}
