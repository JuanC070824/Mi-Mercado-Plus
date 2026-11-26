import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/utils/formato.dart';
import 'package:mimercado_frontend/data/models/cotizacion.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/features/pedido/widgets/detalle_pedido_pago.dart';

final _repo = PedidoRepositoryMock.instancia;

// Pedido de la demo #345-A de María: Doña Rosa y Carnicería Huancayo.
Future<Pedido> _pedidoDemo() async =>
    (await _repo.pedidosCliente('987654321')).firstWhere((p) => p.id == 345);

Future<void> _mostrar(WidgetTester tester, Pedido pedido) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DetallePedidoPago(pedido: pedido)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('antes de pagar se ve a quién le compras y qué compras', (
    tester,
  ) async {
    late Pedido pedido;
    await tester.runAsync(() async {
      // Los caseros que aún no pesaron envían su precio final.
      final inicial = await _pedidoDemo();
      for (final parte in inicial.puestosActivos) {
        if (inicial.cotizacion?.dePuesto(parte.id) != null) continue;
        if (parte.estado == EstadoPedidoPuesto.pendiente) {
          await _repo.aceptarSubpedido(parte.id);
        }
        await _repo.enviarPrecioFinal(parte.id, [
          for (final d in parte.detalles)
            CotizacionDetalle(
              pedidoDetalleId: d.id,
              nombreFinal: d.nombre,
              cantidadReal: d.cantidadSolicitada,
              precioUnitario: d.precioEstimadoUnitario,
            ),
        ]);
      }
      pedido = await _pedidoDemo();
    });
    expect(pedido.cotizacion, isNotNull);
    await _mostrar(tester, pedido);

    expect(find.text('Revisa tu pedido'), findsOneWidget);
    for (final parte in pedido.puestosActivos) {
      expect(find.text(parte.puesto.nombre), findsOneWidget);
      expect(find.text('Casero: ${parte.puesto.casero}'), findsOneWidget);
      for (final d in parte.detalles) {
        expect(
          find.text(
            '${d.nombre} · ${cantidadConUnidad(d.cantidadSolicitada, d.unidad)}',
          ),
          findsOneWidget,
        );
      }
    }
    final total = soles(pedido.cotizacion!.totalCliente);
    expect(find.text('Total a pagar: $total'), findsOneWidget);
    expect(find.text('Llega a: ${pedido.direccion}'), findsOneWidget);

    // Se puede plegar para que no ocupe la pantalla.
    await tester.tap(find.text('Revisa tu pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Llega a: ${pedido.direccion}'), findsNothing);
  });
}
