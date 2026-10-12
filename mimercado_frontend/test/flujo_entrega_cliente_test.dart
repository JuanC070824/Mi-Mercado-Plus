import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/data/models/cotizacion.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';

import 'ayuda_pruebas.dart';

final _repo = PedidoRepositoryMock.instancia;
const _ernesto = '923456789';

/// Lleva el pedido #345-A hasta que Ernesto lo tiene asignado.
Future<void> _hastaRepartidorAsignado() async {
  final parte = (await _repo.pedidosDePuesto(1))
      .firstWhere((p) => p.id == 345)
      .parteDePuesto(1)!;
  await _repo.aceptarSubpedido(parte.id);
  await _repo.enviarPrecioFinal(parte.id, [
    for (final d in parte.detalles)
      CotizacionDetalle(
        pedidoDetalleId: d.id,
        nombreFinal: d.nombre,
        cantidadReal: d.cantidadSolicitada,
        precioUnitario: d.precioEstimadoUnitario,
      ),
  ]);
  await _repo.aceptarCotizacion(345);
  await _repo.aceptarEntrega(345, _ernesto);
}

Future<void> _verMiPedido(WidgetTester tester) async {
  await entrarComo(tester, perfil: 'Cliente', celular: '987654321');
  appRouter.go('/pedido');
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('C6: María ve a su repartidor y la ruta de recojo', (tester) async {
    await tester.runAsync(_hastaRepartidorAsignado);
    await _verMiPedido(tester);
    await verEnLista(tester, find.text('Ernesto Guevara'));
    expect(find.text('Mototaxi · MT-4521'), findsOneWidget);
    await verEnLista(tester, find.text('3. Tu casa'));
  });

  testWidgets('C7 + C7b: en camino muestra el código 4821 y el aviso de llegada',
      (tester) async {
    await tester.runAsync(() async {
      final p = (await _repo.entregaEnCurso(_ernesto))!;
      await _repo.marcarListo(p.parteDePuesto(1)!.id);
      for (final pp in (await _repo.entregaEnCurso(_ernesto))!.puestosActivos) {
        await _repo.marcarRecogido(pp.id);
      }
      await _repo.salirAEntregar(345);
      await _repo.avisarLlegada(345);
    });
    await _verMiPedido(tester);
    expect(find.text('¡Tu repartidor está afuera! Dale el código 4821.'), findsOneWidget);
    await verEnLista(tester, find.text('4821'));
    await verEnLista(tester, find.text('Ya pagaste con Yape'));
  });

  testWidgets('C8 → C9: califica con estrellas y ve el pedido en su historial',
      (tester) async {
    await tester.runAsync(() => _repo.validarCodigoEntrega(345, '4821'));
    await _verMiPedido(tester);
    expect(find.text('¡Pedido entregado!'), findsOneWidget);

    for (final para in ['Doña Rosa Verdulería', 'Carnicería Huancayo', 'Ernesto Guevara']) {
      await tocar(tester, find.byTooltip('5 estrellas para $para'), espera: 100);
    }
    await tocar(tester, find.text('Enviar calificación'));
    expect(find.text('No tienes pedidos en curso'), findsOneWidget);

    await tocar(tester, find.text('Ver mis pedidos anteriores'));
    expect(find.text('#345-A'), findsOneWidget);
    expect(find.text('Entregado'), findsWidgets);
    final p = (await tester.runAsync<List<Pedido>>(() => _repo.pedidosCliente('987654321')))!
        .firstWhere((x) => x.id == 345);
    expect(p.estado, EstadoPedido.entregado);
  });
}
