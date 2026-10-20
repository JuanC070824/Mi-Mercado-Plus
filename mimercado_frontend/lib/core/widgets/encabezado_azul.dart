import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'soporte_dialog.dart';

//Esta es la franja azul de arriba con el logo.

class EncabezadoAzul extends StatelessWidget {
  const EncabezadoAzul({
    super.key,
    required this.titulo,
    this.mostrarAtras = true,
  });

  final String titulo;
  final bool mostrarAtras;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.azul,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Column(
            children: [
              Row(
                children: [
                  if (mostrarAtras)
                    IconButton(
                      tooltip: 'Volver',
                      iconSize: 28,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.blanco,
                      ),
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => mostrarSoporte(context),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(
                      Icons.headset_mic_outlined,
                      color: AppColors.blanco,
                    ),
                    label: const Text(
                      'Soporte',
                      style: TextStyle(
                        color: AppColors.blanco,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.fondo,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Transform.translate(
                    offset: const Offset(
                      -2.5,
                      0,
                    ), // (derecha/izquierda, abajo/arriba)
                    child: Transform.scale(
                      scale: 1.6,
                      child: Image.asset(
                        'assets/images/logo_mimercado.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'Logo de MiMercado+',
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.storefront,
                          size: 48,
                          color: AppColors.azul,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.blanco,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
