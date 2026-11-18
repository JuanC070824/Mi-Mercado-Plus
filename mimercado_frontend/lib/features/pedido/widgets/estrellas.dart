import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// Calificación de 1 a 5 estrellas con botones de 48 dp.
class Estrellas extends StatelessWidget {
  const Estrellas({
    super.key,
    required this.para,
    required this.valor,
    required this.onCambio,
  });

  final String para; // "Doña Rosa Verdulería"
  final int valor; // 0 = sin calificar
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Calificación para {0}: {1} de 5 estrellas', [para, valor]),
      child: Wrap(
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: tr('{0} {1} para {2}', [
                i,
                i == 1 ? tr('estrella') : tr('estrellas'),
                para,
              ]),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              iconSize: 36,
              onPressed: () => onCambio(i),
              icon: Icon(
                i <= valor ? Icons.star_rounded : Icons.star_outline_rounded,
                color: i <= valor ? AppColors.aviso : AppColors.borde,
              ),
            ),
        ],
      ),
    );
  }
}
