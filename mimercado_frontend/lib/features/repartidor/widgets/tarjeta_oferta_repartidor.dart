import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import 'piezas_repartidor.dart';

/// Resumen de un pedido de reparto: cliente, puestos, destino y ganancia.
class TarjetaOfertaRepartidor extends StatelessWidget {
  const TarjetaOfertaRepartidor({
    super.key,
    required this.pedido,
    required this.datos,
  });
  final Pedido pedido;
  final Map<String, dynamic> datos;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pedido.clienteNombre,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            'Recoges en ${pedido.puestosActivos.length} puestos',
            style: const TextStyle(fontSize: 18),
          ),
          Text(pedido.direccion, style: const TextStyle(fontSize: 18)),
          Text(distanciaDe(datos), style: const TextStyle(fontSize: 17)),
          Text(
            'Ganas ${gananciaDe(datos)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.azul,
            ),
          ),
        ],
      ),
    ),
  );
}
