import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/repositories/catalogo_api_repository.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// RF-20: los productos que el cliente repite, para agregarlos con un toque.
class LoQueSiemprePides extends StatelessWidget {
  const LoQueSiemprePides({
    super.key,
    required this.productos,
    required this.onAgregar,
  });

  final List<ProductoFrecuente> productos;
  final ValueChanged<ProductoFrecuente> onAgregar;

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            tr('Lo que siempre pides'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.texto,
            ),
          ),
        ),
        Text(
          tr('Agrégalo de nuevo con un toque.'),
          style: TextStyle(fontSize: 17, color: AppColors.textoSecundario),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < productos.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _Tarjeta(item: productos[i], onAgregar: onAgregar),
        ],
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.item, required this.onAgregar});
  final ProductoFrecuente item;
  final ValueChanged<ProductoFrecuente> onAgregar;

  @override
  Widget build(BuildContext context) {
    final p = item.producto;
    final puedeAgregar = p.disponible && item.puesto.abierto;
    return TarjetaApp(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                Text(
                  '${item.puesto.nombre} · ${soles(p.precioUnitario)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textoSecundario,
                  ),
                ),
                if (!puedeAgregar)
                  Text(
                    item.puesto.abierto
                        ? tr('Hoy no hay')
                        : tr('Puesto cerrado'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: puedeAgregar ? () => onAgregar(item) : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(
              tr('Agregar'),
              semanticsLabel: tr('Agregar {0}', [p.nombre]),
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}
