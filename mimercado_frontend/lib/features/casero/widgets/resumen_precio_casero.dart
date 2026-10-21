import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/cotizacion.dart';

/// Los importes corresponden al puesto, sin sumar envío ni otros vendedores.
class ResumenPrecioCasero extends StatelessWidget {
  const ResumenPrecioCasero({
    super.key,
    required this.estimado,
    required this.detalles,
  });
  final double estimado;
  final List<CotizacionDetalle> detalles;

  @override
  Widget build(BuildContext context) {
    final puesto = CotizacionPuesto(pedidoPuestoId: 0, detalles: detalles);
    return TarjetaApp(
      color: AppColors.azulClaro,
      colorBorde: AppColors.azul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen de tu puesto',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final fila in [
            ('Estimado inicial', estimado),
            ('Precio final', puesto.bruto),
            ('Comisión MiMercado+ (5 %)', puesto.comision),
            ('Recibes', puesto.neto),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: MergeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(fila.$1, style: const TextStyle(fontSize: 18)),
                    Text(
                      soles(fila.$2),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'El envío y los demás puestos se calculan por separado.',
            style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
          ),
        ],
      ),
    );
  }
}
