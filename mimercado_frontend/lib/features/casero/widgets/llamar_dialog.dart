import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';

/// Muestra el número para llamar (sin url_launcher todavía: se copia).
Future<void> mostrarLlamar(BuildContext context, {required String nombre, required String celular}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.call, size: 40, color: AppColors.azul),
      title: Text('Llamar a $nombre',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      content: SelectableText(
        celular,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.azul),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.azul, minimumSize: const Size(48, 56)),
          icon: const Icon(Icons.copy),
          label: const Text('Copiar número', style: TextStyle(fontSize: 18)),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: celular));
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            avisar(context, 'Copiamos el número. Pégalo en tu teléfono para llamar.');
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
