import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../casero/widgets/llamar_dialog.dart';
import '../widgets/piezas_repartidor.dart';

/// Llegada, cobro y código de entrega.
class RepartidorEntregaView extends StatelessWidget {
  const RepartidorEntregaView({
    super.key,
    required this.pedido,
    required this.datos,
    required this.ocupado,
    required this.efectivo,
    required this.codigo,
    required this.alCambiarEfectivo,
    required this.alLlegar,
    required this.alConfirmar,
  });
  final Pedido pedido;
  final Map<String, dynamic> datos;
  final bool ocupado;
  final bool efectivo;
  final TextEditingController codigo;
  final ValueChanged<bool> alCambiarEfectivo;
  final VoidCallback alLlegar;
  final VoidCallback alConfirmar;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final pagado = datos['pago_aprobado'] == true;
    final total = soles(p.cotizacion?.totalCliente ?? 0);
    if (p.estado != EstadoPedido.enCamino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AvisoPantalla(
            icono: Icons.route_outlined,
            titulo: 'Primero completa el recojo en el mercado',
          ),
          AccionRepartidor(
            'Volver a mi ruta',
            () => context.go('/repartidor/ruta'),
            ocupado: ocupado,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloRepartidor(p.clienteNombre),
        Text(p.direccion, style: const TextStyle(fontSize: 20)),
        if (p.referencia?.isNotEmpty ?? false)
          Text(
            'Referencia: ${p.referencia}',
            style: const TextStyle(fontSize: 18),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => mostrarLlamar(
            context,
            nombre: p.clienteNombre,
            celular: p.clienteCelular,
          ),
          icon: const Icon(Icons.call),
          label: const Text(
            'Contactar al cliente',
            style: TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 12),
        EtiquetaEstado(
          texto: p.metodoPago == MetodoPago.efectivo
              ? 'Cobrar $total en efectivo'
              : pagado
              ? datos['pago_simulado'] == true
                    ? 'Pago de demostración confirmado'
                    : 'El cliente ya pagó con Yape'
              : 'El pago todavía está pendiente',
          icono: pagado ? Icons.check_circle : Icons.payments_outlined,
          tipo: pagado ? TipoEstado.exito : TipoEstado.aviso,
        ),
        if (p.metodoPago == MetodoPago.efectivo)
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: efectivo,
              onChanged: ocupado ? null : (v) => alCambiarEfectivo(v == true),
              title: Text(
                'Recibí $total en efectivo',
                style: const TextStyle(fontSize: 19),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        const TituloRepartidor('Código de entrega del cliente'),
        const Text(
          'Pídeselo cuando estés en su dirección y le entregues el pedido. Son 4 números.',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('codigo_entrega'),
          controller: codigo,
          enabled: !ocupado,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 26),
          decoration: const InputDecoration(
            labelText: 'Código del cliente',
            border: OutlineInputBorder(),
          ),
        ),
        OutlinedButton.icon(
          onPressed: ocupado ? null : alLlegar,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.doorbell_outlined),
          label: const Text(
            'Avisar: llegué a tu dirección',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
        AccionRepartidor(
          'Confirmar entrega',
          p.metodoPago == MetodoPago.efectivo && !efectivo ||
                  p.metodoPago == MetodoPago.yape && !pagado
              ? null
              : alConfirmar,
          ocupado: ocupado,
        ),
      ],
    );
  }
}
