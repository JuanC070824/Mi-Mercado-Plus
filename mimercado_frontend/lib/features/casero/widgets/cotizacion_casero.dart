import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/cotizacion.dart';
import 'resumen_precio_casero.dart';

String cantidadExactaCasero(double valor, String simbolo) =>
    '${valor.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '')} $simbolo';

class CotizacionCasero extends StatelessWidget {
  const CotizacionCasero({
    super.key,
    required this.parte,
    required this.cotizacion,
  });
  final PedidoPuesto parte;
  final CotizacionPuesto cotizacion;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Productos y precios finales',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            for (final d in cotizacion.detalles)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${d.nombreFinal} · ${cantidadExactaCasero(d.cantidadReal, parte.detalles.where((p) => p.id == d.pedidoDetalleId).firstOrNull?.unidad.simbolo ?? '')} · ${soles(d.subtotal)}',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            if (cotizacion.nota?.trim().isNotEmpty ?? false)
              Text(
                'Nota: ${cotizacion.nota}',
                style: const TextStyle(fontSize: 18),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ResumenPrecioCasero(
        estimado: parte.subtotalEstimado,
        detalles: cotizacion.detalles,
      ),
    ],
  );
}

class SeguimientoPuestoCasero extends StatelessWidget {
  const SeguimientoPuestoCasero({super.key, required this.estado});
  final EstadoPedidoPuesto estado;
  @override
  Widget build(BuildContext context) {
    final paso = switch (estado) {
      EstadoPedidoPuesto.pesado => 1,
      EstadoPedidoPuesto.enPreparacion => 2,
      EstadoPedidoPuesto.listo => 3,
      EstadoPedidoPuesto.recogido => 4,
      _ => 0,
    };
    const pasos = [
      'Pedido aceptado',
      'Precio enviado',
      'Preparando la bolsa',
      'Listo para recojo',
      'Bolsa entregada al repartidor',
    ];
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Estado de tu parte',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          for (var i = 0; i < pasos.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      i < paso
                          ? Icons.check_circle
                          : i == paso
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: i <= paso
                          ? AppColors.azul
                          : AppColors.textoSecundario,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${pasos[i]}${i == paso
                            ? ' · Ahora'
                            : i < paso
                            ? ' · Completado'
                            : ' · Pendiente'}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
