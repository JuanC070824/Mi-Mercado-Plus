import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';

/// Abre el marcador del teléfono. Se puede reemplazar en pruebas.
@visibleForTesting
Future<bool> Function(Uri) abrirMarcador = launchUrl;

/// En el celular abre el marcador con el número; en la web se copia.
Future<void> mostrarLlamar(
  BuildContext context, {
  required String nombre,
  required String celular,
}) {
  Future<void> copiar(BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: celular));
    if (!ctx.mounted) return;
    Navigator.of(ctx).pop();
    avisar(context, 'Copiamos el número. Pégalo en tu teléfono para llamar.');
  }

  Future<void> llamar(BuildContext ctx) async {
    var abierto = false;
    try {
      abierto = await abrirMarcador(Uri(scheme: 'tel', path: '+51$celular'));
    } catch (_) {}
    if (!ctx.mounted) return;
    if (abierto) {
      Navigator.of(ctx).pop();
    } else {
      await copiar(ctx);
    }
  }

  final botonPrincipal = FilledButton.styleFrom(
    backgroundColor: AppColors.azul,
    minimumSize: const Size(48, 56),
  );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.call, size: 40, color: AppColors.azul),
      title: Text(
        'Llamar a $nombre',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      content: SelectableText(
        celular,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppColors.azul,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        if (kIsWeb)
          FilledButton.icon(
            style: botonPrincipal,
            icon: const Icon(Icons.copy),
            label: const Text('Copiar número', style: TextStyle(fontSize: 18)),
            onPressed: () => copiar(ctx),
          )
        else ...[
          FilledButton.icon(
            style: botonPrincipal,
            icon: const Icon(Icons.call),
            label: const Text('Llamar', style: TextStyle(fontSize: 18)),
            onPressed: () => llamar(ctx),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.copy),
            label: const Text('Copiar número', style: TextStyle(fontSize: 18)),
            onPressed: () => copiar(ctx),
          ),
        ],
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cerrar', style: TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
}
