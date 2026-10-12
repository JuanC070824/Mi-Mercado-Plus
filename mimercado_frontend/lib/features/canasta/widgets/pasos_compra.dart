import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// "Paso 1 de 3": Canasta → Entrega y pago → ¡Listo!
class PasosCompra extends StatelessWidget {
  const PasosCompra({super.key, required this.paso});

  final int paso; // 1, 2 o 3

  static const _nombres = ['Canasta', 'Entrega y pago', '¡Listo!'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso $paso de 3: ${_nombres[paso - 1]}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso $paso de 3 · ${_nombres[paso - 1]}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.azul,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 3; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= paso ? AppColors.azul : AppColors.divisor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
