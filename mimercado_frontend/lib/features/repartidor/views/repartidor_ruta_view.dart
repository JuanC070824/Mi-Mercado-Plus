import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../widgets/piezas_repartidor.dart';

/// Recojo por paradas: solo la parada que toca tiene botón.
class RepartidorRutaView extends StatelessWidget {
  const RepartidorRutaView({
    super.key,
    required this.pedido,
    required this.ocupado,
    required this.alRecoger,
    required this.alAvisar,
    required this.alSalir,
  });
  final Pedido pedido;
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
    final faltan = partes.length - recogidos;
    final listo = partes.isNotEmpty && faltan == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pedido de ${pedido.clienteNombre}',
          style: const TextStyle(
            fontSize: 17,
            color: AppColors.textoSecundario,
          ),
        ),
        TituloRepartidor('Recogidos $recogidos de ${partes.length} puestos'),
        LinearProgressIndicator(
          value: partes.isEmpty ? 0 : recogidos / partes.length,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          semanticsLabel: 'Avance del recojo: $recogidos de ${partes.length}',
        ),
        if (!listo)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: ocupado ? null : alAvisar,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text(
                'Avisar: estoy recogiendo',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ),
        for (final pp in partes)
          _Parada(
            parte: pp,
            habilitada: pp.id == siguiente,
            ocupado: ocupado,
            alRecoger: () => alRecoger(pp),
          ),
        const SizedBox(height: 8),
        if (!listo)
          Text(
            faltan == 1 ? 'Falta 1 bolsa.' : 'Faltan $faltan bolsas.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textoSecundario,
            ),
          ),
        AccionRepartidor(
          'Ir a entregar',
          listo ? alSalir : null,
          ocupado: ocupado,
        ),
      ],
    );
  }
}

class _Parada extends StatelessWidget {
  const _Parada({
    required this.parte,
    required this.habilitada,
    required this.ocupado,
    required this.alRecoger,
  });
  final PedidoPuesto parte;
  final bool habilitada;
  final bool ocupado;
  final VoidCallback alRecoger;

  @override
  Widget build(BuildContext context) {
    final recogida = parte.estado == EstadoPedidoPuesto.recogido;
    final lista = parte.estado == EstadoPedidoPuesto.listo;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TarjetaApp(
        color: recogida ? AppColors.fondo : AppColors.blanco,
        colorBorde: habilitada ? AppColors.azul : AppColors.borde,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${parte.parada}. ${parte.puesto.nombre}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Atiende: ${parte.puesto.casero}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: recogida
                        ? const EtiquetaEstado(
                            texto: 'Recogida',
                            icono: Icons.done_all,
                            tipo: TipoEstado.exito,
                          )
                        : lista
                        ? const EtiquetaEstado(
                            texto: 'Lista para recoger',
                            icono: Icons.shopping_bag_outlined,
                            tipo: TipoEstado.exito,
                          )
                        : const EtiquetaEstado(
                            texto: 'Preparando',
                            icono: Icons.hourglass_top,
                          ),
                  ),
                ],
              ),
            ),
            if (habilitada && lista)
              AccionRepartidor('Recogí la bolsa', alRecoger, ocupado: ocupado)
            else if (habilitada)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Espera a que el casero la tenga lista.',
                  style: TextStyle(fontSize: 17),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
