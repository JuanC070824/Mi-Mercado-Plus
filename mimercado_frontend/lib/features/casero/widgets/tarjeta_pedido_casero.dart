import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';

/// Resumen de la parte que corresponde al vendedor, sin sumar otros puestos.
class TarjetaPedidoCasero extends StatelessWidget {
  const TarjetaPedidoCasero({
    super.key,
    required this.pedido,
    required this.parte,
    required this.onTap,
  });

  final Pedido pedido;
  final PedidoPuesto parte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cantidad = parte.detalles.length;
    final cotizacion = pedido.cotizacion;
    final cotizacionPuesto = cotizacion?.dePuesto(parte.id);
    final precioFinal =
        cotizacionPuesto != null &&
        (cotizacion?.estado == EstadoCotizacion.enviada ||
            cotizacion?.estado == EstadoCotizacion.aceptada);
    final monto = precioFinal ? cotizacionPuesto.bruto : parte.subtotalEstimado;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.blanco,
        foregroundColor: AppColors.texto,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(16),
        side: BorderSide(
          color: parte.estado == EstadoPedidoPuesto.pendiente
              ? AppColors.azul
              : AppColors.borde,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pedido ${pedido.codigo}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.azul,
                  ),
                ),
              ),
              const ExcludeSemantics(
                child: Icon(Icons.chevron_right, color: AppColors.azul),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: etiquetaDePuesto(parte.estado),
          ),
          const SizedBox(height: 16),
          Text(
            pedido.clienteNombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$cantidad ${cantidad == 1 ? 'producto' : 'productos'} · '
            '${fechaCorta(pedido.creadoEn.toLocal())}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textoSecundario,
            ),
          ),
          if ((parte.listaMandado ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Con lista de mandado', style: TextStyle(fontSize: 16)),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                precioFinal
                    ? 'Precio final de tu puesto'
                    : 'Estimado de tu puesto',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textoSecundario,
                ),
              ),
              Text(
                soles(monto),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
