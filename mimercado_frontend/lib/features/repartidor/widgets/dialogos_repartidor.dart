import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/pedido.dart';
import 'piezas_repartidor.dart';

Widget _dialogo(List<Widget> children) => Dialog(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  ),
);

/// Oferta de un pedido nuevo. Devuelve true si el repartidor la acepta.
Future<bool?> mostrarOfertaRepartidor(
  BuildContext context, {
  required Pedido pedido,
  required Map<String, dynamic> datos,
}) => showDialog<bool>(
  context: context,
  builder: (ctx) => _dialogo([
    const Icon(Icons.delivery_dining, size: 48, color: AppColors.azul),
    const TituloRepartidor('¡Nuevo pedido para recoger!'),
    Text(
      'Cliente: ${pedido.clienteNombre}',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    TituloRepartidor('Recoges en ${pedido.puestosActivos.length} puestos'),
    for (final parte in pedido.puestosActivos)
      Text(
        '${parte.parada}. ${parte.puesto.nombre}',
        style: const TextStyle(fontSize: 18),
      ),
    const SizedBox(height: 12),
    Text(
      'Entregas en: ${pedido.direccion}',
      style: const TextStyle(fontSize: 18),
    ),
    Text(distanciaDe(datos), style: const TextStyle(fontSize: 17)),
    const SizedBox(height: 12),
    Text(
      'Ganas ${gananciaDe(datos)}',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.azul,
      ),
    ),
    Text(
      pedido.metodoPago == MetodoPago.efectivo
          ? 'El cliente paga en efectivo al recibir.'
          : datos['pago_simulado'] == true
          ? 'Pago de demostración confirmado. No se movió dinero.'
          : 'El pago con Yape ya está confirmado.',
      style: const TextStyle(fontSize: 18),
    ),
    const SizedBox(height: 16),
    FilledButton(
      style: estiloBotonRepartidor,
      onPressed: () => Navigator.of(ctx).pop(true),
      child: const Text(
        'Aceptar reparto',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20),
      ),
    ),
    TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: () => Navigator.of(ctx).pop(false),
      child: const Text('Ahora no', style: TextStyle(fontSize: 18)),
    ),
  ]),
);

/// Confirmación antes de un paso que no se puede deshacer.
Future<bool> confirmarRepartidor(
  BuildContext context,
  String titulo,
  String texto,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => _dialogo([
        TituloRepartidor(titulo),
        Text(texto, style: const TextStyle(fontSize: 19)),
        const SizedBox(height: 16),
        FilledButton(
          style: estiloBotonRepartidor,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sí, confirmar', style: TextStyle(fontSize: 20)),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Volver a revisar', style: TextStyle(fontSize: 18)),
        ),
      ]),
    ) ??
    false;

/// Cierre del reparto con la ganancia obtenida.
Future<void> mostrarEntregado(BuildContext context, String ganancia) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _dialogo([
        const Icon(Icons.celebration, size: 50, color: AppColors.azul),
        const TituloRepartidor('¡Pedido entregado!'),
        Text(
          'Ganaste $ganancia por este reparto.',
          style: const TextStyle(fontSize: 21),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: estiloBotonRepartidor,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(
            'Volver al inicio',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ]),
    );
