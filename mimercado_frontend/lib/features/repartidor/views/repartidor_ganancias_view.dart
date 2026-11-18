import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../widgets/piezas_repartidor.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// Entregas y ganancia del día.
class ResumenGananciasRepartidor extends StatelessWidget {
  const ResumenGananciasRepartidor({super.key, required this.inicio});
  final Map<String, dynamic> inicio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TituloRepartidor(tr('Tu trabajo de hoy')),
      TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('{0} entregas completadas', [inicio['entregas_hoy'] ?? 0]),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            Text(
              tr('Ganaste {0}', [
                soles(
                  ((inicio['ganancia_hoy_centavos'] as num?) ?? 0).toDouble() /
                      100,
                ),
              ]),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.azul,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class RepartidorGananciasView extends StatelessWidget {
  const RepartidorGananciasView({super.key, required this.inicio});
  final Map<String, dynamic> inicio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ResumenGananciasRepartidor(inicio: inicio),
      const SizedBox(height: 12),
      TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Ganancias acumuladas'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              soles(
                ((inicio['ganancia_acumulada_centavos'] as num?) ?? 0)
                        .toDouble() /
                    100,
              ),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.azul,
              ),
            ),
            Text(
              tr(
                'Entregas completadas con pago confirmado. Registro interno; no representa un depósito bancario.',
              ),
            ),
          ],
        ),
      ),
      for (final j in inicio['historial_hoy'] as List? ?? [])
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TarjetaApp(
            child: Text(
              '${j['cliente_nombre']} · ${gananciaDe(Map<String, dynamic>.from(j))}',
              style: const TextStyle(fontSize: 19),
            ),
          ),
        ),
    ],
  );
}
