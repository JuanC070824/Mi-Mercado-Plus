import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Número de la central de ayuda (dato de prueba).
const numeroSoporte = '01 640 9000';

/// Ventana "¿Necesitas ayuda?" del botón Soporte 🎧 (todas las pantallas).
Future<void> mostrarSoporte(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.headset_mic_outlined, size: 40, color: AppColors.azul),
      title: const Text(
        '¿Necesitas ayuda?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Llámanos y una persona te atiende. Te ayudamos con tu pedido, '
            'tu pago o tu cuenta.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: AppColors.texto),
          ),
          SizedBox(height: 16),
          Text(
            'Lunes a sábado, de 6:00 a 20:00',
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
          label: const Text('Llamar a soporte', style: TextStyle(fontSize: 18)),
          onPressed: () async {
            // Sin url_launcher todavía: se copia el número para marcarlo.
            await Clipboard.setData(const ClipboardData(text: numeroSoporte));
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Copiamos el número $numeroSoporte. Pégalo en tu teléfono para llamar.',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            );
          },
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cerrar', style: TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
}
