import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ItemNavegacion {
  const ItemNavegacion({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.imagen,
  });

  final String etiqueta;
  final IconData icono; // respaldo si no existe la imagen
  final IconData iconoActivo;
  final String imagen; // ilustración opcional en assets/images/
}

/// Menú del cliente: Inicio · Canasta · Mi pedido · Perfil.
const itemsCliente = [
  ItemNavegacion(
    etiqueta: 'Inicio',
    icono: Icons.storefront_outlined,
    iconoActivo: Icons.storefront_rounded,
    imagen: 'assets/images/nav_inicio.png',
  ),
  ItemNavegacion(
    etiqueta: 'Canasta',
    icono: Icons.shopping_basket_outlined,
    iconoActivo: Icons.shopping_basket_rounded,
    imagen: 'assets/images/nav_canasta.png',
  ),
  ItemNavegacion(
    etiqueta: 'Mi pedido',
    icono: Icons.inventory_2_outlined,
    iconoActivo: Icons.inventory_2_rounded,
    imagen: 'assets/images/nav_pedido.png',
  ),
  ItemNavegacion(
    etiqueta: 'Perfil',
    icono: Icons.account_circle_outlined,
    iconoActivo: Icons.account_circle_rounded,
    imagen: 'assets/images/nav_perfil.png',
  ),
];

/// Menú del casero: Inicio · Pedidos · Catálogo · Mi puesto.
const itemsCasero = [
  ItemNavegacion(
    etiqueta: 'Inicio',
    icono: Icons.home_outlined,
    iconoActivo: Icons.home_rounded,
    imagen: 'assets/images/nav_inicio.png',
  ),
  ItemNavegacion(
    etiqueta: 'Pedidos',
    icono: Icons.receipt_long_outlined,
    iconoActivo: Icons.receipt_long_rounded,
    imagen: 'assets/images/nav_pedidos.png',
  ),
  ItemNavegacion(
    etiqueta: 'Catálogo',
    icono: Icons.inventory_2_outlined,
    iconoActivo: Icons.inventory_2_rounded,
    imagen: 'assets/images/nav_catalogo.png',
  ),
  ItemNavegacion(
    etiqueta: 'Mi puesto',
    icono: Icons.storefront_outlined,
    iconoActivo: Icons.storefront_rounded,
    imagen: 'assets/images/nav_puesto.png',
  ),
];

/// Menú del repartidor: Inicio · Ruta · Ganancias · Perfil.
const itemsRepartidor = [
  ItemNavegacion(
    etiqueta: 'Inicio',
    icono: Icons.home_outlined,
    iconoActivo: Icons.home_rounded,
    imagen: 'assets/images/nav_inicio.png',
  ),
  ItemNavegacion(
    etiqueta: 'Ruta',
    icono: Icons.route_outlined,
    iconoActivo: Icons.route_rounded,
    imagen: 'assets/images/nav_ruta.png',
  ),
  ItemNavegacion(
    etiqueta: 'Ganancias',
    icono: Icons.payments_outlined,
    iconoActivo: Icons.payments_rounded,
    imagen: 'assets/images/nav_ganancias.png',
  ),
  ItemNavegacion(
    etiqueta: 'Perfil',
    icono: Icons.account_circle_outlined,
    iconoActivo: Icons.account_circle_rounded,
    imagen: 'assets/images/nav_perfil.png',
  ),
];

/// Menú horizontal inferior. Seleccionado = fondo azul claro + borde azul + texto
/// en negrita (no depende solo del color), igual que las tarjetas de rubro.
class BarraNavegacionApp extends StatelessWidget {
  const BarraNavegacionApp({
    super.key,
    required this.indiceActual,
    required this.onSeleccion,
    this.items = itemsCliente,
  });

  final int indiceActual;
  final ValueChanged<int> onSeleccion;
  final List<ItemNavegacion> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.blanco,
        border: Border(top: BorderSide(color: AppColors.borde, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _ElementoNavegacion(
                    item: items[i],
                    seleccionado: i == indiceActual,
                    onTap: () => onSeleccion(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElementoNavegacion extends StatelessWidget {
  const _ElementoNavegacion({
    required this.item,
    required this.seleccionado,
    required this.onTap,
  });

  final ItemNavegacion item;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? AppColors.azul : AppColors.textoSecundario;

    return Semantics(
      button: true,
      selected: seleccionado,
      label: item.etiqueta,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          seleccionado ? AppColors.azulClaro : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: seleccionado ? AppColors.azul : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _IconoNavegacion(
                      item: item,
                      seleccionado: seleccionado,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.etiqueta,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.15,
                      fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Imagen ilustrada si existe el archivo; si no, un ícono con tus colores.
class _IconoNavegacion extends StatelessWidget {
  const _IconoNavegacion({
    required this.item,
    required this.seleccionado,
    required this.color,
  });

  final ItemNavegacion item;
  final bool seleccionado;
  final Color color;

  static const double _tamano = 30;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _tamano,
      height: _tamano,
      child: Image.asset(
        item.imagen,
        fit: BoxFit.contain,
        excludeFromSemantics: true, // decorativa: el texto ya dice la sección
        errorBuilder: (context, error, stack) => Icon(
          seleccionado ? item.iconoActivo : item.icono,
          size: _tamano,
          color: color,
        ),
      ),
    );
  }
}