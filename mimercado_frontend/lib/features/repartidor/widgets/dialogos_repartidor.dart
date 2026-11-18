import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/pedido.dart';
import 'piezas_repartidor.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

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
    TituloRepartidor(tr('¡Nuevo pedido para recoger!')),
    Text(
      tr('Cliente: {0}', [pedido.clienteNombre]),
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    TituloRepartidor(
      tr('Recoges en {0} puestos', [pedido.puestosActivos.length]),
    ),
    for (final parte in pedido.puestosActivos)
      Text(
        '${parte.parada}. ${parte.puesto.nombre}',
        style: const TextStyle(fontSize: 18),
      ),
    const SizedBox(height: 12),
    Text(
      tr('Entregas en: {0}', [pedido.direccion]),
      style: const TextStyle(fontSize: 18),
    ),
    Text(distanciaDe(datos), style: const TextStyle(fontSize: 17)),
    const SizedBox(height: 12),
    Text(
      tr('Ganas {0}', [gananciaDe(datos)]),
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.azul,
      ),
    ),
    Text(
      pedido.metodoPago == MetodoPago.efectivo
          ? tr('El cliente paga en efectivo al recibir.')
          : datos['pago_proveedor'] == 'mercadopago_prueba'
          ? tr('Pago confirmado con Mercado Pago.')
          : pedido.metodoPago == MetodoPago.plin
          ? tr(
              'El cliente paga con Plin al recibir. Confirma el cobro en la entrega.',
            )
          : datos['pago_simulado'] == true
          ? tr('Pago de demostración confirmado. No se movió dinero.')
          : tr('El pago con Yape ya está confirmado.'),
      style: const TextStyle(fontSize: 18),
    ),
    const SizedBox(height: 16),
    FilledButton(
      style: estiloBotonRepartidor,
      onPressed: () => Navigator.of(ctx).pop(true),
      child: Text(
        tr('Aceptar reparto'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20),
      ),
    ),
    TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: () => Navigator.of(ctx).pop(false),
      child: Text(tr('Ahora no'), style: TextStyle(fontSize: 18)),
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
          child: Text(tr('Sí, confirmar'), style: TextStyle(fontSize: 20)),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr('Volver a revisar'), style: TextStyle(fontSize: 18)),
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
        TituloRepartidor(tr('¡Pedido entregado!')),
        Text(
          tr('Ganaste {0} por este reparto.', [ganancia]),
          style: const TextStyle(fontSize: 21),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: estiloBotonRepartidor,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            tr('Volver al inicio'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ]),
    );
