import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Estado persistente del pago confirmado por el servidor.
class AvisoPagoPedido extends StatelessWidget {
  const AvisoPagoPedido({super.key, required this.datos, this.ganancia});
  final Map<String, dynamic> datos;
  final int? ganancia;

  @override
  Widget build(BuildContext context) {
    if (datos['pago_confirmado'] != true) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.exitoFondo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pago confirmado · ${datos['pago_metodo'] ?? 'Cliente'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.exitoTexto,
              ),
            ),
            const Text('El cliente ya pagó este pedido.'),
            if (ganancia != null)
              Text(
                'Tu ganancia: S/ ${(ganancia! / 100).toStringAsFixed(2)}. '
                'Se acumula al completar la entrega.',
              ),
          ],
        ),
      ),
    );
  }
}
