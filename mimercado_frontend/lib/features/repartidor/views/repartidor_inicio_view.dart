import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/repartidor.dart';
import '../widgets/piezas_repartidor.dart';
import '../widgets/tarjeta_oferta_repartidor.dart';

/// Disponibilidad arriba y, debajo, la entrega en curso o las ofertas.
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
    final movilidad = Movilidad.desdeCodigo(
      inicio['movilidad']?.toString(),
    ).etiqueta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaApp(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => context.go('/repartidor/perfil'),
                icon: const Icon(Icons.delivery_dining_outlined),
                label: Text(
                  movilidad,
                  semanticsLabel: 'Movilidad: $movilidad. Cambiar en Perfil',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              MergeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        disponible ? 'Disponible' : 'No disponible',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: disponible,
                      onChanged: ocupado ? null : alCambiarDisponible,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (actual case final p?)
          _EntregaEnCurso(pedido: p, alContinuar: alContinuar, ocupado: ocupado)
        else ...[
          const TituloRepartidor('Pedidos de tu mercado'),
          if (ofertas.isEmpty)
            AvisoPantalla(
              icono: Icons.delivery_dining,
              titulo: disponible
                  ? 'Aún no hay pedidos'
                  : 'No estás recibiendo pedidos',
              texto: disponible
                  ? 'Te avisaremos cuando llegue uno.'
                  : 'Activa «Disponible» para recibirlos.',
            ),
          for (final p in ofertas)
            TarjetaOfertaRepartidor(
              pedido: p,
              datos: datosDe(p.id),
              alVer: () => alVerOferta(p),
              ocupado: ocupado,
            ),
        ],
      ],
    );
  }
}

class _EntregaEnCurso extends StatelessWidget {
  const _EntregaEnCurso({
    required this.pedido,
    required this.alContinuar,
    required this.ocupado,
  });
  final Pedido pedido;
  final VoidCallback alContinuar;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    final partes = pedido.puestosActivos;
    final recogidos = partes
        .where((x) => x.estado == EstadoPedidoPuesto.recogido)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TarjetaApp(
        colorBorde: AppColors.azul,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloRepartidor('Entrega en curso'),
            Text(
              pedido.clienteNombre,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              pedido.estado == EstadoPedido.enCamino
                  ? 'En camino a ${pedido.direccion}'
                  : 'Recogidos $recogidos de ${partes.length} puestos',
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textoSecundario,
              ),
            ),
            const SizedBox(height: 8),
            AccionRepartidor(
              'Continuar mi entrega',
              alContinuar,
              ocupado: ocupado,
            ),
          ],
        ),
      ),
    );
  }
}
