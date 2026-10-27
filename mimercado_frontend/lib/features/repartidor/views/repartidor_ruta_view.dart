import 'package:flutter/material.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../widgets/piezas_repartidor.dart';
import '../widgets/tarjeta_oferta_repartidor.dart';

/// Recojo de las bolsas en el orden de las paradas.
class RepartidorRutaView extends StatelessWidget {
  const RepartidorRutaView({
    super.key,
    required this.pedido,
    required this.datos,
    required this.ocupado,
    required this.alRecoger,
    required this.alAvisar,
    required this.alSalir,
  });
  final Pedido pedido;
  final Map<String, dynamic> datos;
  final bool ocupado;
  final ValueChanged<PedidoPuesto> alRecoger;
  final VoidCallback alAvisar;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    final partes = [...pedido.puestosActivos]
      ..sort((a, b) => a.parada.compareTo(b.parada));
    final recogidos = partes
        .where((x) => x.estado == EstadoPedidoPuesto.recogido)
        .length;
    final siguiente = partes
        .where((x) => x.estado != EstadoPedidoPuesto.recogido)
        .firstOrNull
        ?.id;
    final listo = partes.isNotEmpty && recogidos == partes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaOfertaRepartidor(pedido: pedido, datos: datos),
        TituloRepartidor('Recogidos $recogidos de ${partes.length} puestos'),
        LinearProgressIndicator(
          value: partes.isEmpty ? 0 : recogidos / partes.length,
          minHeight: 10,
          semanticsLabel: 'Avance del recojo: $recogidos de ${partes.length}',
        ),
        const SizedBox(height: 12),
        const Text(
          'Sigue el orden de las paradas. Confirma el recojo cuando tengas la bolsa en la mano.',
          style: TextStyle(fontSize: 18),
        ),
        for (final pp in partes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TarjetaApp(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${pp.parada}. ${pp.puesto.nombre}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Atiende: ${pp.puesto.casero}',
                    style: const TextStyle(fontSize: 17),
                  ),
                  etiquetaDePuesto(pp.estado),
                  if (pp.estado != EstadoPedidoPuesto.recogido)
                    AccionRepartidor(
                      'Recogí la bolsa',
                      pp.id == siguiente &&
                              pp.estado == EstadoPedidoPuesto.listo
                          ? () => alRecoger(pp)
                          : null,
                      ocupado: ocupado,
                    ),
                  if (pp.estado == EstadoPedidoPuesto.enPreparacion)
                    const Text(
                      'El vendedor está preparando esta bolsa.',
                      style: TextStyle(fontSize: 17),
                    ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: ocupado ? null : alAvisar,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.message_outlined),
          label: const Text(
            'Avisar: estoy recogiendo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
        if (!listo)
          const Text(
            'Recoge en todos los puestos para poder ir a entregar.',
            style: TextStyle(fontSize: 18),
          ),
        AccionRepartidor(
          'Ya recogí todo · Ir a entregar',
          listo ? alSalir : null,
          ocupado: ocupado,
        ),
      ],
    );
  }
}
