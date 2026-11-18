import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';

/// Accesos de Inicio con los mismos destinos que el menú del vendedor.
class AccesosInicioCasero extends StatelessWidget {
  const AccesosInicioCasero({
    super.key,
    required this.onVerPedidos,
    required this.onVerCatalogo,
  });

  final VoidCallback onVerPedidos;
  final VoidCallback onVerCatalogo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Accesos rápidos'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // Con letra grande se apilan, sin reducir ni recortar el texto.
            final apilar =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(18) >= 27;
            final ancho = apilar
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: ancho,
                  child: _Acceso(
                    texto: 'Mis pedidos',
                    icono: Icons.assignment_outlined,
                    onPressed: onVerPedidos,
                  ),
                ),
                SizedBox(
                  width: ancho,
                  child: _Acceso(
                    texto: 'Mi catálogo',
                    icono: Icons.shopping_basket_outlined,
                    onPressed: onVerCatalogo,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({
    required this.texto,
    required this.icono,
    required this.onPressed,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style:
          OutlinedButton.styleFrom(
            backgroundColor: AppColors.blanco,
            foregroundColor: AppColors.azul,
            minimumSize: const Size(48, 96),
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith((states) {
              final enfocado = states.contains(WidgetState.focused);
              return BorderSide(
                color: enfocado ? AppColors.azul : AppColors.borde,
                width: enfocado ? 3 : 1.5,
              );
            }),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icono, size: 32)),
          const SizedBox(height: 8),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
