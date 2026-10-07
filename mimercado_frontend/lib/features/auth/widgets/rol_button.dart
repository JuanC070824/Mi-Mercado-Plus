import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RolButton extends StatelessWidget {
  const RolButton({
    super.key,
    required this.etiqueta,
    required this.imagen,
    required this.onTap,
  });

  final String etiqueta;
  final String imagen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Entrar como $etiqueta',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    imagen,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.person,
                      size: 76,
                      color: AppColors.azul,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.azul,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}