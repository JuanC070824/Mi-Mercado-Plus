import 'package:flutter/material.dart';
import '../../data/models/producto.dart';
import '../theme/app_colors.dart';
import '../utils/formato.dart';

/// Control "−  1.5 kg  +" con botones de 48 dp.
/// Lo usan la canasta del cliente (C2, C3) y la balanza del casero (V3).
class ControlCantidad extends StatelessWidget {
  const ControlCantidad({
    super.key,
    required this.cantidad,
    required this.unidad,
    required this.nombre,
    required this.onRestar,
    required this.onSumar,
  });

  final double cantidad;
  final UnidadMedida unidad;
  final String nombre; // para el lector de pantalla: "Quitar 0.5 kg de Tomate"
  final VoidCallback? onRestar;
  final VoidCallback? onSumar;

  @override
  Widget build(BuildContext context) {
    final paso = cantidadConUnidad(unidad.paso, unidad);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotonRedondo(
          icono: Icons.remove,
          etiqueta: 'Quitar $paso de $nombre',
          relleno: false,
          onPressed: onRestar,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 76),
          child: Semantics(
            liveRegion: true,
            label: '$nombre: ${cantidadConUnidad(cantidad, unidad)}',
            excludeSemantics: true,
            child: Text(
              cantidadConUnidad(cantidad, unidad),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.texto,
              ),
            ),
          ),
        ),
        _BotonRedondo(
          icono: Icons.add,
          etiqueta: 'Agregar $paso de $nombre',
          relleno: true,
          onPressed: onSumar,
        ),
      ],
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.etiqueta,
    required this.relleno,
    required this.onPressed,
  });

  final IconData icono;
  final String etiqueta;
  final bool relleno;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: etiqueta,
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: relleno
            ? IconButton.filled(
                onPressed: onPressed,
                style: IconButton.styleFrom(backgroundColor: AppColors.azul),
                icon: Icon(icono, size: 26, color: AppColors.blanco),
              )
            : IconButton.outlined(
                onPressed: onPressed,
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.azul, width: 2),
                ),
                icon: Icon(icono, size: 26, color: AppColors.azul),
              ),
      ),
    );
  }
}
