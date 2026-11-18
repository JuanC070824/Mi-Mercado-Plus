import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';

class RevisionProductoCasero extends StatelessWidget {
  const RevisionProductoCasero({
    super.key,
    required this.detalle,
    required this.habilitado,
    required this.onTap,
  });
  final PedidoDetalle detalle;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icono, tipo) = switch (detalle.disponibilidad) {
      Disponibilidad.pendiente => (Icons.help_outline, TipoEstado.neutro),
      Disponibilidad.disponible => (
        Icons.check_circle_outline,
        TipoEstado.exito,
      ),
      Disponibilidad.sinStock => (
        Icons.remove_shopping_cart_outlined,
        TipoEstado.error,
      ),
      Disponibilidad.reemplazo => (Icons.swap_horiz, TipoEstado.aviso),
    };
    return OutlinedButton(
      onPressed: habilitado ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texto,
        backgroundColor: AppColors.blanco,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(16),
        side: const BorderSide(color: AppColors.borde, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            detalle.nombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Pidió: ${cantidadConUnidad(detalle.cantidadSolicitada, detalle.unidad)}',
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: EtiquetaEstado(
              texto: detalle.disponibilidad.etiqueta,
              icono: icono,
              tipo: tipo,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cambiar disponibilidad',
            style: TextStyle(
              fontSize: 17,
              color: AppColors.azul,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Future<Disponibilidad?> elegirDisponibilidadProducto(
  BuildContext context,
  PedidoDetalle detalle,
) {
  Disponibilidad? elegida = detalle.disponibilidad == Disponibilidad.pendiente
      ? null
      : detalle.disponibilidad;
  return showModalBottomSheet<Disponibilidad>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Disponibilidad de ${detalle.nombre}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<Disponibilidad>(
              groupValue: elegida,
              onChanged: (valor) => setState(() => elegida = valor),
              child: Column(
                children: [
                  for (final estado in [
                    Disponibilidad.disponible,
                    Disponibilidad.sinStock,
                    Disponibilidad.reemplazo,
                  ])
                    RadioListTile<Disponibilidad>(
                      value: estado,
                      title: Text(
                        estado.etiqueta,
                        style: const TextStyle(fontSize: 19),
                      ),
                      subtitle: Text(switch (estado) {
                        Disponibilidad.disponible =>
                          'Entregarás el producto solicitado.',
                        Disponibilidad.sinStock =>
                          'Este producto no se incluirá al pesar.',
                        _ =>
                          'Indica el reemplazo al pesar. El cliente confirmará el precio final.',
                      }, style: const TextStyle(fontSize: 16)),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.azul,
                foregroundColor: AppColors.blanco,
                minimumSize: const Size(48, 56),
                padding: const EdgeInsets.all(16),
              ),
              onPressed: elegida == null || elegida == detalle.disponibilidad
                  ? null
                  : () => Navigator.of(ctx).pop(elegida),
              child: const Text(
                'Guardar disponibilidad',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    ),
  );
}
