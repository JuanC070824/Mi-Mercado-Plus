import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/mercado.dart';
import '../../../data/models/puesto.dart';

/// Imagen del rubro; si el archivo no existe, muestra un ícono.
class ImagenCategoria extends StatelessWidget {
  const ImagenCategoria(this.categoria, {super.key, this.tamano = 64});

  final CategoriaPuesto categoria;
  final double tamano;

  static IconData _icono(CategoriaPuesto c) => switch (c) {
    CategoriaPuesto.verduras => Icons.eco_rounded,
    CategoriaPuesto.carnes => Icons.kebab_dining_rounded,
    CategoriaPuesto.abarrotes => Icons.shopping_basket_rounded,
    CategoriaPuesto.pescados => Icons.set_meal_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Image.asset(
        categoria.imagen,
        fit: BoxFit.contain,
        excludeFromSemantics: true, // decorativa: el texto ya dice el rubro
        errorBuilder: (context, error, stack) =>
            Icon(_icono(categoria), size: tamano * 0.75, color: AppColors.azul),
      ),
    );
  }
}

/// "Ver estado de mi pedido" / "Mi carrito de compras".

/// Tarjeta de rubro. Seleccionada = borde azul grueso + check (no solo color).
class TarjetaCategoria extends StatelessWidget {
  const TarjetaCategoria({
    super.key,
    required this.categoria,
    required this.seleccionada,
    required this.onTap,
  });

  final CategoriaPuesto categoria;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionada,
      label: categoria.nombre,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: seleccionada ? AppColors.azulClaro : AppColors.blanco,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: seleccionada ? AppColors.azul : AppColors.borde,
            width: seleccionada ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 140),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImagenCategoria(categoria, tamano: 64),
                        const SizedBox(height: 8),
                        Text(
                          categoria.nombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (seleccionada)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.azul,
                    size: 26,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra "Selecciona tu mercado". Con mercado elegido muestra su nombre y distancia.
class BarraMercado extends StatelessWidget {
  const BarraMercado({
    super.key,
    required this.mercado,
    required this.onTap,
    this.distanciaTexto,
  });

  final Mercado? mercado;
  final String? distanciaTexto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = mercado;
    return Semantics(
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      label: m == null
          ? 'Selecciona tu mercado'
          : 'Mercado seleccionado: ${m.nombre}. ${distanciaTexto ?? ''} Toca para cambiar.',
      child: Material(
        color: AppColors.blanco,
        clipBehavior: Clip.antiAlias,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.azul, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  if (m != null) ...[
                    const Icon(
                      Icons.location_on,
                      color: AppColors.azul,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: m == null
                        ? const Text(
                            'Selecciona tu mercado',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.texto,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.nombre,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.texto,
                                ),
                              ),
                              if (distanciaTexto != null)
                                Text(
                                  distanciaTexto!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textoSecundario,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  m == null
                      ? const Icon(
                          Icons.search,
                          color: AppColors.azul,
                          size: 28,
                        )
                      : const Text(
                          'Cambiar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.azul,
                            decoration: TextDecoration.underline,
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

class TarjetaCasero extends StatelessWidget {
  const TarjetaCasero({
    super.key,
    required this.puesto,
    required this.onTap,
    this.nombreMercado,
  });

  final Puesto puesto;
  final VoidCallback onTap;
  final String? nombreMercado; // solo cuando aún no hay mercado elegido

  @override
  Widget build(BuildContext context) {
    final p = puesto;
    final nota = p.calificacion.toStringAsFixed(1);
    final textoResenas =
        '${p.resenas} ${p.resenas == 1 ? 'reseña' : 'reseñas'}';

    return Semantics(
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      label:
          '${p.nombre}. Casero ${p.casero}. Calificación $nota de 5, '
          '$textoResenas. ${p.abierto ? 'Abierto' : 'Cerrado'}.'
          '${nombreMercado == null ? '' : ' $nombreMercado.'}',
      child: Material(
        color: AppColors.blanco,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.borde, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3EBDD),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: ImagenCategoria(p.categoria, tamano: 48),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.texto,
                        ),
                      ),
                      Text(
                        'Casero: ${p.casero}',
                        style: const TextStyle(
                          fontSize: 17,
                          color: AppColors.textoSecundario,
                        ),
                      ),
                      if (nombreMercado != null)
                        Text(
                          nombreMercado!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.azul,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.calificacion,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: AppColors.texto,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$nota · $textoResenas',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.texto,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                p.abierto ? Icons.check_circle : Icons.schedule,
                                size: 18,
                                color: p.abierto
                                    ? AppColors.exito
                                    : AppColors.textoSecundario,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                p.abierto ? 'Abierto' : 'Cerrado',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: p.abierto
                                      ? AppColors.exito
                                      : AppColors.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
