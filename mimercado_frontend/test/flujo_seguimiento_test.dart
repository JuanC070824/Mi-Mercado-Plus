import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/data/models/cotizacion.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';

import 'ayuda_pruebas.dart';

final _repo = PedidoRepositoryMock.instancia;

/// Lleva el pedido #345-A hasta "Confirma el precio final" (tomate 1.5 kg).
Future<void> rosaPesaElPedido() async {
  final parte = (await _repo.pedidosDePuesto(1))
      .firstWhere((p) => p.id == 345)
      .parteDePuesto(1)!;
  await _repo.aceptarSubpedido(parte.id);
  await _repo.enviarPrecioFinal(parte.id, [
    for (final d in parte.detalles)
      CotizacionDetalle(
        pedidoDetalleId: d.id,
        nombreFinal: d.nombre,
        cantidadReal: d.nombre == 'Tomate' ? 1.5 : d.cantidadSolicitada,
        precioUnitario: d.precioEstimadoUnitario,
      ),
  ], nota: 'el tomate pesó 1.5 kg');
}

Future<void> _abrirMiPedido(WidgetTester tester) async {
  await entrarComo(tester, perfil: 'Cliente', celular: '987654321');
  appRouter.go('/pedido');
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('C5: María ve que Carnicería ya pesó y Doña Rosa aún no',
      (tester) async {
    await _abrirMiPedido(tester);
    expect(find.text('Mi pedido #345-A'), findsOneWidget);
    expect(find.text('AHORA'), findsOneWidget);
    expect(find.text('Ya pesó'), findsWidgets); // Carnicería (simulada)
    expect(find.text('Nuevo pedido'), findsOneWidget); // Doña Rosa aún no acepta
  });

  testWidgets('C5b: llega el precio final (S/ 48.00) y María lo acepta',
      (tester) async {
    await tester.runAsync(rosaPesaElPedido);
    await _abrirMiPedido(tester);

    expect(find.text('Tus caseros ya pesaron'), findsOneWidget); // se abre sola
    expect(find.text('Nota del casero: "el tomate pesó 1.5 kg"'), findsOneWidget);
    await verEnLista(tester, find.text('Total final'));
    expect(find.text('S/ 48.00'), findsOneWidget);
    await tocar(tester, find.text('Aceptar y continuar'));

    final p = (await tester.runAsync<Pedido?>(() => _repo.pedidoActivoCliente('987654321')))!;
    expect(p.cotizacion!.estado, EstadoCotizacion.aceptada);
    expect(p.parteDePuesto(3)!.estado, EstadoPedidoPuesto.listo); // simulado
    expect(p.parteDePuesto(1)!.estado, EstadoPedidoPuesto.enPreparacion);
    expect(find.text('Tus caseros ya pesaron'), findsNothing);
  });

  testWidgets('V4 → V5: Rosa empaqueta deslizando y entrega la bolsa 345-A-1',
      (tester) async {
    await entrarComo(tester, perfil: 'Comerciante', celular: '912345678');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tocar(tester, find.textContaining('#345-A'));
    expect(find.textContaining('aceptó el precio final'), findsOneWidget);

    // V4: deslizar el círculo hasta el final
    await verEnLista(tester, find.text('Desliza: ya empaqueté'));
    await tester.drag(find.byIcon(Icons.chevron_right), const Offset(400, 0));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    Pedido p = (await tester.runAsync<Pedido?>(() => _repo.pedidoActivoCliente('987654321')))!;
    expect(p.parteDePuesto(1)!.estado, EstadoPedidoPuesto.listo);
    expect(p.estado, EstadoPedido.listoParaRecojo);

    // V5: checklist + entregar
    await verEnLista(tester, find.text('#345-A-1'));
    expect(find.text('Bolsa 1 de 2'), findsOneWidget);
    for (final nombre in ['Tomate · 1.5 kg', 'Papa amarilla · 2 kg', 'Limón · 0.5 kg']) {
      await tocar(tester, find.text(nombre), espera: 100);
    }
    await tocar(tester, find.text('Ya se lo entregué'));
    p = (await tester.runAsync<Pedido?>(() => _repo.pedidoActivoCliente('987654321')))!;
    expect(p.parteDePuesto(1)!.estado, EstadoPedidoPuesto.recogido);
    expect(p.estado, EstadoPedido.enRecojo);
  });
}
