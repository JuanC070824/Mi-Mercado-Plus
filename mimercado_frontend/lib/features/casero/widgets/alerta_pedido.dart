import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../canasta/widgets/opcion_elegible.dart';

/// Texto del aviso de pedido compartido: con qué otros puestos y en qué orden recoge.
String? textoCompartido(Pedido pedido, PedidoPuesto parte) {
  final otros = [
    for (final p in pedido.puestosActivos)
      if (p.id != parte.id) p.puesto.nombre,
  ];
  if (otros.isEmpty) return null;
  final orden = parte.parada == 1
      ? 'El repartidor recoge primero en tu puesto'
      : 'El repartidor pasa por tu puesto en la parada ${parte.parada}';
  return 'Pedido compartido con ${otros.join(' y ')} · $orden';
}

/// Lista "Tomate — 1 kg" de la parte del pedido de un puesto.
class ListaProductosParte extends StatelessWidget {
  const ListaProductosParte({super.key, required this.parte});
  final PedidoPuesto parte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in parte.detalles)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '• ${d.nombre} — ${cantidadConUnidad(d.cantidadSolicitada, d.unidad)}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        if (parte.listaMandado != null) ...[
          const SizedBox(height: 8),
          TarjetaApp(
            color: AppColors.avisoFondo,
            colorBorde: AppColors.aviso,
            padding: const EdgeInsets.all(12),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note, color: AppColors.aviso),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text('Lista de mandado',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  Text(parte.listaMandado!, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// V1b · Ventana grande "¡NUEVO PEDIDO!" con sonido y vibración.
/// Devuelve true = Aceptar, false = Rechazar, null = verlo después.
Future<bool?> mostrarNuevoPedido(
  BuildContext context, {
  required Pedido pedido,
  required PedidoPuesto parte,
  required Usuario casero,
}) {
  if (casero.sonido) SystemSound.play(SystemSoundType.alert);
  if (casero.vibracion) HapticFeedback.heavyImpact();
  final compartido = textoCompartido(pedido, parte);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.notifications_active, size: 48, color: AppColors.azul),
      title: Semantics(
        liveRegion: true,
        child: const Text(
          '¡NUEVO PEDIDO!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${pedido.codigoCorto} · ${pedido.clienteNombre}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListaProductosParte(parte: parte),
            const SizedBox(height: 8),
            Text(
              'Estimado: ${soles(parte.subtotalEstimado)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (compartido != null) ...[
              const SizedBox(height: 12),
              EtiquetaEstado(
                texto: compartido,
                icono: Icons.people_outline,
                tipo: TipoEstado.info,
              ),
            ],
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.azul,
              minimumSize: const Size(48, 56),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Aceptar pedido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 2),
              minimumSize: const Size(48, 56),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            icon: const Icon(Icons.close),
            label: const Text('Rechazar', style: TextStyle(fontSize: 20)),
          ),
        ),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Verlo después', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    ),
  );
}

/// V1c · Motivo del rechazo. Elegir el motivo y tocar "Sí, rechazar" es la
/// confirmación (acción que no se puede deshacer). Devuelve null si cancela.
Future<MotivoRechazo?> elegirMotivoRechazo(BuildContext context) {
  return showModalBottomSheet<MotivoRechazo>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      MotivoRechazo? elegido;
      return StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '¿Por qué no puedes atenderlo?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Le avisamos al cliente para que lo pida en otro puesto.',
                  style: TextStyle(fontSize: 17, color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 12),
                for (final m in MotivoRechazo.values) ...[
                  OpcionElegible(
                    titulo: m.etiqueta,
                    icono: switch (m) {
                      MotivoRechazo.faltaStock => Icons.remove_shopping_cart_outlined,
                      MotivoRechazo.cerrando => Icons.lock_clock,
                      MotivoRechazo.muchosPedidos => Icons.hourglass_bottom,
                    },
                    elegida: elegido == m,
                    onTap: () => setState(() => elegido = m),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(48, 56),
                    shape: const StadiumBorder(),
                  ),
                  onPressed:
                      elegido == null ? null : () => Navigator.of(ctx).pop(elegido),
                  child: const Text('Sí, rechazar pedido',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('No, volver', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Pide el motivo y rechaza. Devuelve true si se rechazó.
Future<bool> rechazarConMotivo(BuildContext context, PedidoPuesto parte) async {
  final motivo = await elegirMotivoRechazo(context);
  if (motivo == null) return false;
  try {
    await PedidoRepositoryMock.instancia.rechazarSubpedido(parte.id, motivo.etiqueta);
    if (context.mounted) avisar(context, 'Rechazaste el pedido. Le avisamos al cliente.');
    return true;
  } on PedidoException catch (e) {
    if (context.mounted) avisar(context, e.mensaje);
    return false;
  }
}
