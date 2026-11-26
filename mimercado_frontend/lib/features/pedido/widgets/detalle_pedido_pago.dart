import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// «Revisa tu pedido» antes de pagar: a quién le compras, qué compras, cuánto
/// y a dónde llega. Usa el precio final si ya existe; si no, el estimado.
class DetallePedidoPago extends StatelessWidget {
  const DetallePedidoPago({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final cotizacion = pedido.cotizacion;
    final envio = cotizacion?.costoEnvio ?? pedido.costoEnvio;
    final total = cotizacion?.totalCliente ?? pedido.totalEstimado;
    return TarjetaApp(
      padding: EdgeInsets.zero,
      child: Theme(
        // Sin las líneas que ExpansionTile dibuja al abrirse.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        // Material propio: la tarjeta tiene fondo y ocultaría el efecto al tocar.
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.receipt_long, color: AppColors.azul),
            title: Text(
              tr('Revisa tu pedido'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              tr('Total a pagar: {0}', [soles(total)]),
              style: const TextStyle(fontSize: 17, color: AppColors.texto),
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final parte in pedido.puestosActivos) ...[
                _Puesto(pedido: pedido, parte: parte),
                const Divider(color: AppColors.divisor, height: 24),
              ],
              FilaMonto(etiqueta: tr('Envío'), monto: envio),
              FilaMonto(
                etiqueta: tr('Total a pagar'),
                monto: total,
                destacado: true,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.home_outlined, color: AppColors.azul),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Llega a: {0}', [pedido.direccion]),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Puesto extends StatelessWidget {
  const _Puesto({required this.pedido, required this.parte});

  final Pedido pedido;
  final PedidoPuesto parte;

  @override
  Widget build(BuildContext context) {
    final final_ = pedido.cotizacion?.dePuesto(parte.id);
    final unidades = {for (final d in parte.detalles) d.id: d.unidad};
    // Precio final del casero; si aún no pesó, lo que pediste con su estimado.
    final lineas = final_ != null
        ? [
            for (final d in final_.detalles)
              if (unidades[d.pedidoDetalleId] != null)
                (
                  nombre: d.nombreFinal,
                  cantidad: cantidadConUnidad(
                    d.cantidadReal,
                    unidades[d.pedidoDetalleId]!,
                  ),
                  monto: d.subtotal,
                ),
          ]
        : [
            for (final d in parte.detalles)
              (
                nombre: d.nombre,
                cantidad: cantidadConUnidad(d.cantidadSolicitada, d.unidad),
                monto: d.subtotalEstimado,
              ),
          ];
    final subtotal = final_?.bruto ?? parte.subtotalEstimado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppColors.azul),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                parte.puesto.nombre,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (parte.puesto.casero.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(
              tr('Casero: {0}', [parte.puesto.casero]),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textoSecundario,
              ),
            ),
          ),
        const SizedBox(height: 8),
        for (final l in lineas)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${l.nombre} · ${l.cantidad}',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  Text(soles(l.monto), style: const TextStyle(fontSize: 17)),
                ],
              ),
            ),
          ),
        if (parte.listaMandado != null && parte.listaMandado!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 6),
            child: Text(
              tr('Lista de mandado: {0}', [parte.listaMandado]),
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: AppColors.textoSecundario,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: FilaMonto(etiqueta: tr('Subtotal'), monto: subtotal),
        ),
      ],
    );
  }
}
