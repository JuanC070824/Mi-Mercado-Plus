import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Opción grande para elegir una entre varias (método de pago, ¿cuándo?).
/// Elegida = borde azul grueso + ícono de check + texto "Elegido" para el lector.
class OpcionElegible extends StatelessWidget {
  const OpcionElegible({
    super.key,
    required this.titulo,
    required this.icono,
    required this.elegida,
    required this.onTap,
    this.detalle,
  });

  final String titulo;
  final String? detalle;
  final IconData icono;
  final bool elegida;
  final VoidCallback? onTap; // null = no disponible

  @override
  Widget build(BuildContext context) {
    final activa = onTap != null;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: elegida,
      enabled: activa,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: elegida ? AppColors.azulClaro : AppColors.blanco,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: elegida ? AppColors.azul : AppColors.borde,
              width: elegida ? 3 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icono,
                  size: 30,
                  color: activa ? AppColors.azul : AppColors.textoSecundario),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: activa ? AppColors.texto : AppColors.textoSecundario,
                      ),
                    ),
                    if (detalle != null)
                      Text(
                        detalle!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                elegida ? Icons.check_circle : Icons.radio_button_unchecked,
                color: elegida ? AppColors.azul : AppColors.borde,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
