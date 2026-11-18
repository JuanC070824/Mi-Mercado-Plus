import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Este es el botón azul y el botón con borde
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: cargando ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.azul,
          foregroundColor: AppColors.blanco,
          disabledBackgroundColor: AppColors.azul,
          disabledForegroundColor: AppColors.blanco,
          shape: const StadiumBorder(),
        ),
        child: cargando
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.blanco,
                  semanticsLabel: 'Cargando',
                ),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class BotonSecundario extends StatelessWidget {
  const BotonSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  final String texto;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azul,
          side: const BorderSide(color: AppColors.azul, width: 2),
          shape: const StadiumBorder(),
        ),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
