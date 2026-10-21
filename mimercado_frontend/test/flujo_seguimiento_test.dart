import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/core/widgets/componentes_app.dart';
import 'package:mimercado_frontend/data/models/cotizacion.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_vendedor_api_repository.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/features/casero/screens/casero_pedido_screen.dart';
import 'package:mimercado_frontend/features/repartidor/screens/repartidor_inicio_screen.dart';
import 'package:mimercado_frontend/features/repartidor/screens/ruta_screen.dart';
import 'package:mimercado_frontend/features/repartidor/screens/entrega_screen.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';

import 'ayuda_pruebas.dart';

final _repo = PedidoRepositoryMock.instancia;

class _PedidosVendedorPrueba extends PedidosVendedorApiRepository {
  @override
  Future<List<Pedido>> pedidosDePuesto(int id) => _repo.pedidosDePuesto(id);
  @override
  Future<void> marcarListo(int id) => _repo.marcarListo(id);
  @override
  Future<void> entregarARepartidor(int id) => _repo.entregarARepartidor(id);
}

/// Lleva el pedido #345-A hasta "Confirma el precio final" (tomate 1.5 kg).
Future<void> rosaPesaElPedido() async {
  final parte = (await _repo.pedidosDePuesto(
    1,
  )).firstWhere((p) => p.id == 345).parteDePuesto(1)!;
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
  testWidgets('C5: María ve que Carnicería ya pesó y Doña Rosa aún no', (
    tester,
  ) async {
    await _abrirMiPedido(tester);
    expect(find.text('Mi pedido'), findsWidgets);
    expect(find.text('AHORA'), findsOneWidget);
    expect(find.text('Precio enviado'), findsWidgets); // Carnicería (simulada)
    expect(
      find.text('Nuevo pedido'),
      findsOneWidget,
    ); // Doña Rosa aún no acepta
  });

  testWidgets('C5b: llega el precio final (S/ 48.00) y María lo acepta', (
    tester,
  ) async {
    await tester.runAsync(rosaPesaElPedido);
    await _abrirMiPedido(tester);

    expect(find.text('Tus caseros ya pesaron'), findsOneWidget); // se abre sola
    expect(
      find.text('Nota del casero: "el tomate pesó 1.5 kg"'),
      findsOneWidget,
    );
    await verEnLista(tester, find.text('Total final'));
    expect(find.text('S/ 48.00'), findsOneWidget);
    await tocar(tester, find.text('Aceptar y continuar'));

    final p = (await tester.runAsync<Pedido?>(
      () => _repo.pedidoActivoCliente('987654321'),
    ))!;
    expect(p.cotizacion!.estado, EstadoCotizacion.aceptada);
    expect(p.parteDePuesto(3)!.estado, EstadoPedidoPuesto.listo); // simulado
    expect(p.parteDePuesto(1)!.estado, EstadoPedidoPuesto.enPreparacion);
    expect(find.text('Tus caseros ya pesaron'), findsNothing);
  });

  testWidgets(
    'V4 → V5: Rosa confirma la preparación y entrega sin mostrar códigos internos',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CaseroPedidoScreen(
            pedidoId: 345,
            usuario: const Usuario(
              nombres: 'Rosa',
              celular: '912345678',
              rol: Rol.comerciante,
              puestoId: 1,
            ),
            repository: _PedidosVendedorPrueba(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('aceptó el precio final'), findsOneWidget);

      // V4: deslizar el círculo hasta el final
      await tocar(tester, find.text('Ya empaqueté: marcar listo'));
      await tocar(tester, find.text('Sí, está lista'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      Pedido p = (await tester.runAsync<Pedido?>(
        () => _repo.pedidoActivoCliente('987654321'),
      ))!;
      expect(p.parteDePuesto(1)!.estado, EstadoPedidoPuesto.listo);
      expect(p.estado, EstadoPedido.listoParaRecojo);

      // V5: checklist + entregar
      await verEnLista(tester, find.text('Bolsa para entregar'));
      expect(find.textContaining('345-A'), findsNothing);
      for (final nombre in [
        'Tomate · 1.5 kg',
        'Papa amarilla · 2 kg',
        'Limón · 0.5 kg',
      ]) {
        await tocar(tester, find.text(nombre), espera: 100);
      }
      await tocar(tester, find.text('Ya se lo entregué'));
      await tocar(tester, find.text('Sí, entregué la bolsa'));
      p = (await tester.runAsync<Pedido?>(
        () => _repo.pedidoActivoCliente('987654321'),
      ))!;
      expect(p.parteDePuesto(1)!.estado, EstadoPedidoPuesto.recogido);
      expect(p.estado, EstadoPedido.enRecojo);
    },
  );

  testWidgets('R1 → R2 → R3: Ernesto toma #345-A, recoge y entrega con 4821', (
    tester,
  ) async {
    // Prototipo histórico aislado: el router de la app ya no permite acceder a estos mocks.
    const usuario = Usuario(
      nombres: 'Ernesto',
      celular: '923456789',
      rol: Rol.repartidor,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/repartidor/inicio',
      routes: [
        GoRoute(
          path: '/repartidor/inicio',
          builder: (_, _) => const RepartidorInicioScreen(usuario: usuario),
        ),
        GoRoute(
          path: '/repartidor/ruta',
          builder: (_, _) => const RutaScreen(usuario: usuario),
        ),
        GoRoute(
          path: '/repartidor/ruta/entrega',
          builder: (_, _) => const EntregaScreen(usuario: usuario),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await verEnLista(tester, find.text('Mototaxi · MT-4521'));
    expect(find.text('Mototaxi · MT-4521'), findsOneWidget);
    await verEnLista(tester, find.textContaining('recojo en 2 puestos'));

    // El orden depende de la hora local: elige al cliente, no la primera tarjeta.
    final tarjeta = find.ancestor(
      of: find.textContaining('María Esperanza · recojo'),
      matching: find.byType(TarjetaApp),
    );
    await verEnLista(tester, find.textContaining('María Esperanza · recojo'));
    await tocar(
      tester,
      find.descendant(of: tarjeta, matching: find.text('Aceptar pedido')),
    );
    await verEnLista(tester, find.text('Recogidos 1 de 2'));
    expect(
      find.text('Recogidos 1 de 2'),
      findsOneWidget,
    ); // Doña Rosa ya entregó

    // R2: no puede salir hasta recoger en la Carnicería
    await verEnLista(
      tester,
      find.text('Recoge en todos los puestos para poder ir a entregar'),
    );
    await tocar(tester, find.text('Recogí la bolsa'));
    expect(
      find.text('Recoge en todos los puestos para poder ir a entregar'),
      findsNothing,
    );
    await tocar(tester, find.text('Ir a entregar'));

    // R3: código equivocado y luego el correcto
    expect(find.text('Ya pagó con Yape'), findsOneWidget);
    expect(find.text('S/ 48.00'), findsOneWidget);
    await verEnLista(
      tester,
      find.widgetWithText(TextField, 'Código del cliente'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Código del cliente'),
      '1111',
    );
    await tocar(tester, find.text('O toca aquí: entregado'));
    expect(
      find.text('El código no coincide. Pídeselo de nuevo al cliente.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Código del cliente'),
      '4821',
    );
    await tocar(tester, find.text('O toca aquí: entregado'));
    expect(find.text('¡Pedido entregado!'), findsOneWidget);
    await tocar(tester, find.text('Volver al inicio'));
    expect(find.text('entregas hoy'), findsOneWidget);
    expect(find.text('S/ 5.00'), findsOneWidget); // ganado hoy

    final p = (await tester.runAsync<List<Pedido>>(
      () => _repo.pedidosCliente('987654321'),
    ))!.firstWhere((x) => x.id == 345);
    expect(p.estado, EstadoPedido.entregado);
  });

  test('salirAEntregar devuelve false si falta recoger un puesto', () async {
    final p344 = (await _repo.pedidosParaRepartidor(
      1,
    )).firstWhere((p) => p.id == 344);
    expect(await _repo.salirAEntregar(p344.id), isFalse);
  });
}
