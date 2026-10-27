import 'package:flutter/material.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/repartidor.dart';
import '../widgets/piezas_repartidor.dart';
import '../widgets/tarjeta_oferta_repartidor.dart';
import 'repartidor_ganancias_view.dart';

/// Disponibilidad, entrega en curso u ofertas del mercado.
class RepartidorInicioView extends StatelessWidget {
  const RepartidorInicioView({
    super.key,
    required this.inicio,
    required this.actual,
    required this.ofertas,
    required this.datosDe,
    required this.ocupado,
    required this.alCambiarDisponible,
    required this.alVerOferta,
    required this.alContinuar,
  });
  final Map<String, dynamic> inicio;
  final Pedido? actual;
  final List<Pedido> ofertas;
  final Map<String, dynamic> Function(int id) datosDe;
  final bool ocupado;
  final ValueChanged<bool> alCambiarDisponible;
  final ValueChanged<Pedido> alVerOferta;
  final VoidCallback alContinuar;

  @override
  Widget build(BuildContext context) {
    final disponible = inicio['disponible'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Movilidad: ${Movilidad.desdeCodigo(inicio['movilidad']?.toString()).etiqueta}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const Text(
          'Puedes cambiarla desde Perfil cuando termines tu entrega.',
          style: TextStyle(fontSize: 17),
        ),
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: disponible,
            onChanged: ocupado ? null : alCambiarDisponible,
            title: const Text(
              'Disponible para recibir pedidos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              disponible
                  ? 'Recibes ofertas de tu mercado.'
                  : 'No recibirás nuevas ofertas. Puedes terminar tu entrega actual.',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),
        ResumenGananciasRepartidor(inicio: inicio),
        if (actual case final p?) ...[
          const TituloRepartidor('Entrega en curso'),
          TarjetaOfertaRepartidor(pedido: p, datos: datosDe(p.id)),
          AccionRepartidor(
            'Continuar mi entrega',
            alContinuar,
            ocupado: ocupado,
          ),
        ] else ...[
          const TituloRepartidor('Pedidos de tu mercado'),
          if (ofertas.isEmpty)
            const AvisoPantalla(
              icono: Icons.delivery_dining,
              titulo: 'Todavía no hay pedidos para recoger',
              texto:
                  'Con tu disponibilidad activada, aparecerán aquí cuando el cliente confirme su pedido y el pago correspondiente.',
            ),
          for (final p in ofertas) ...[
            TarjetaOfertaRepartidor(pedido: p, datos: datosDe(p.id)),
            AccionRepartidor(
              'Ver y aceptar reparto',
              () => alVerOferta(p),
              ocupado: ocupado,
            ),
          ],
        ],
      ],
    );
  }
}
