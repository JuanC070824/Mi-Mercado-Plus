import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../casero/widgets/llamar_dialog.dart';
import '../widgets/piezas_repartidor.dart';

/// Entrega en dos pasos: 1) llegar a la dirección, 2) cobrar y pedir el código.
class RepartidorEntregaView extends StatelessWidget {
  const RepartidorEntregaView({
    super.key,
    required this.pedido,
    required this.datos,
    required this.ocupado,
    required this.llegue,
    required this.efectivo,
    required this.codigo,
    required this.alCambiarEfectivo,
    required this.alLlegar,
    required this.alVolverALlegada,
    required this.alConfirmar,
  });
  final Pedido pedido;
  final Map<String, dynamic> datos;
  final bool ocupado;

  /// true cuando el aviso de llegada ya se envió: muestra el paso 2.
  final bool llegue;
  final bool efectivo;
  final TextEditingController codigo;
  final ValueChanged<bool> alCambiarEfectivo;
  final VoidCallback alLlegar;
  final VoidCallback alVolverALlegada;
  final VoidCallback alConfirmar;

  @override
  Widget build(BuildContext context) {
    if (pedido.estado != EstadoPedido.enCamino) {
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
        Text(
          llegue ? 'Paso 2 de 2 · Cobro y código' : 'Paso 1 de 2 · Llegada',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textoSecundario,
          ),
        ),
        ...llegue ? _cobro(context) : _llegada(context),
      ],
    );
  }

  List<Widget> _llegada(BuildContext context) => [
    TituloRepartidor(pedido.clienteNombre),
    Text(pedido.direccion, style: const TextStyle(fontSize: 20)),
    if (pedido.referencia?.isNotEmpty ?? false)
      Text(
        'Referencia: ${pedido.referencia}',
        style: const TextStyle(fontSize: 17, color: AppColors.textoSecundario),
      ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => mostrarLlamar(
          context,
          nombre: pedido.clienteNombre,
          celular: pedido.clienteCelular,
        ),
        icon: const Icon(Icons.call),
        label: const Text(
          'Contactar al cliente',
          style: TextStyle(fontSize: 17),
        ),
      ),
    ),
    const SizedBox(height: 8),
    AccionRepartidor('Llegué a la dirección', alLlegar, ocupado: ocupado),
  ];

  List<Widget> _cobro(BuildContext context) {
    final pagado = datos['pago_aprobado'] == true;
    final enEfectivo = pedido.metodoPago == MetodoPago.efectivo;
    final total = soles(pedido.cotizacion?.totalCliente ?? 0);
    return [
      TituloRepartidor(pedido.clienteNombre),
      if (enEfectivo) ...[
        Text(
          'Cobra $total',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.azul,
          ),
        ),
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
      ] else
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: EtiquetaEstado(
            texto: pagado
                ? datos['pago_simulado'] == true
                      ? 'Pago de demostración confirmado'
                      : 'El cliente ya pagó con Yape'
                : 'El pago todavía está pendiente',
            icono: pagado ? Icons.check_circle : Icons.payments_outlined,
            tipo: pagado ? TipoEstado.exito : TipoEstado.aviso,
          ),
        ),
      const SizedBox(height: 16),
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
          helperText: 'Los 4 números que te dicta el cliente',
          helperStyle: TextStyle(fontSize: 16),
          border: OutlineInputBorder(),
        ),
      ),
      AccionRepartidor(
        'Confirmar entrega',
        enEfectivo && !efectivo || !enEfectivo && !pagado ? null : alConfirmar,
        ocupado: ocupado,
      ),
      Align(
        child: TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: ocupado ? null : alVolverALlegada,
          child: const Text(
            'Ver la dirección otra vez',
            style: TextStyle(fontSize: 17),
          ),
        ),
      ),
    ];
  }
}
