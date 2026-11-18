import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// Número de la central de ayuda (dato de prueba).
const numeroSoporte = '01 640 9000';

/// Ventana "¿Necesitas ayuda?" del botón Soporte 🎧 (todas las pantallas).
Future<void> mostrarSoporte(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.headset_mic_outlined,
        size: 40,
        color: AppColors.azul,
      ),
      title: Text(
        tr('¿Necesitas ayuda?'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(
              'Llámanos y una persona te atiende. Te ayudamos con tu pedido, tu pago o tu cuenta.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: AppColors.texto),
          ),
          SizedBox(height: 16),
          Text(
            tr('Lunes a sábado, de 6:00 a 20:00'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
          ),
          SizedBox(height: 8),
          SelectableText(
            numeroSoporte,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.azul,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 56),
            backgroundColor: AppColors.azul,
          ),
          icon: const Icon(Icons.call),
          label: Text(tr('Llamar a soporte'), style: TextStyle(fontSize: 18)),
          onPressed: () async {
            // Sin url_launcher todavía: se copia el número para marcarlo.
            await Clipboard.setData(const ClipboardData(text: numeroSoporte));
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr(
                    'Copiamos el número {0}. Pégalo en tu teléfono para llamar.',
                    [numeroSoporte],
                  ),
                  style: TextStyle(fontSize: 18),
                ),
              ),
            );
          },
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('Cerrar'), style: TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
}
