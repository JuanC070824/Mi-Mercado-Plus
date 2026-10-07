import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Cuadro rojo de error

class MensajeError extends StatelessWidget {
  const MensajeError(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true, // el lector de pantalla lo anuncia al aparecer
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}