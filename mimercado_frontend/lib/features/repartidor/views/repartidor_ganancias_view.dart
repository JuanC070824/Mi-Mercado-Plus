import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../widgets/piezas_repartidor.dart';

/// Entregas y ganancia del día.
class ResumenGananciasRepartidor extends StatelessWidget {
  const ResumenGananciasRepartidor({super.key, required this.inicio});
  final Map<String, dynamic> inicio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const TituloRepartidor('Tu trabajo de hoy'),
      TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${inicio['entregas_hoy'] ?? 0} entregas completadas',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            Text(
              'Ganaste ${soles(((inicio['ganancia_hoy_centavos'] as num?) ?? 0).toDouble() / 100)}',
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
