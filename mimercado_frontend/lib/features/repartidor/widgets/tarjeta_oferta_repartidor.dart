import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import 'piezas_repartidor.dart';

/// Oferta compacta: lo justo para decidir. El detalle va en el diálogo.
class TarjetaOfertaRepartidor extends StatelessWidget {
  const TarjetaOfertaRepartidor({
    super.key,
    required this.pedido,
    required this.datos,
    required this.alVer,
    this.ocupado = false,
  });
  final Pedido pedido;
  final Map<String, dynamic> datos;
  final VoidCallback alVer;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    final puestos = pedido.puestosActivos.length;
    final km = distanciaCortaDe(datos);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pedido.clienteNombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    [
                      '$puestos ${puestos == 1 ? 'puesto' : 'puestos'}',
                      ?km,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ganas ${gananciaDe(datos)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.azul,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            AccionRepartidor('Ver y aceptar', alVer, ocupado: ocupado),
          ],
        ),
      ),
    );
  }
}
