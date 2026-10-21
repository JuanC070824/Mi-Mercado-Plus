import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/models/producto.dart';
import 'package:mimercado_frontend/data/models/puesto.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_vendedor_api_repository.dart';
import 'package:mimercado_frontend/features/casero/screens/casero_pedido_screen.dart';
import 'package:mimercado_frontend/features/casero/widgets/revision_producto_casero.dart';

class _Pedidos extends PedidosVendedorApiRepository {
  final estados = <int, Disponibilidad>{100: Disponibilidad.pendiente};
  final notificador = ValueNotifier(0);
  int cargas = 0;
  int guardados = 0;
  bool fallarGuardado = false;
  bool fallarCarga = false;
  Completer<void>? pendiente;

  @override
  ValueNotifier<int> get cambios => notificador;

  @override
  Future<List<Pedido>> pedidosDePuesto(int puestoId) async {
    cargas++;
    if (fallarCarga) {
      throw const PedidoException('No pudimos consultar el pedido.');
    }
    return [
      Pedido(
        id: 1,
        codigo: 'MM-1',
        codigoCorto: '1',
        clienteNombre: 'María',
        clienteCelular: '900000001',
        mercadoId: 1,
        estado: EstadoPedido.enPreparacion,
        metodoPago: MetodoPago.efectivo,
        direccion: 'Dirección de prueba',
        costoEnvio: 5,
        historial: [],
        codigoEntrega: '',
        creadoEn: DateTime(2026, 10, 20),
        puestos: [
          PedidoPuesto(
            id: 10,
            puesto: const Puesto(
              id: 1,
              mercadoId: 1,
              nombre: 'Verduras Rosa',
              casero: 'Rosa',
              categoria: CategoriaPuesto.verduras,
              calificacion: 0,
              resenas: 0,
            ),
            codigoBolsa: 'MM-1-1',
            estado: EstadoPedidoPuesto.aceptado,
            parada: 1,
            detalles: [
              for (final entrada in estados.entries)
                PedidoDetalle(
                  id: entrada.key,
                  nombre: entrada.key == 100 ? 'Tomate' : 'Papa',
                  unidad: UnidadMedida.kg,
                  cantidadSolicitada: 1,
                  precioEstimadoUnitario: 4,
                  disponibilidad: entrada.value,
                ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<void> marcarDisponibilidad(int id, Disponibilidad estado) async {
    guardados++;
    if (fallarGuardado) {
      throw const PedidoException('No pudimos guardar la disponibilidad.');
    }
    if (pendiente != null) await pendiente!.future;
    estados[id] = estado;
    notificador.value++;
  }
}

Future<void> _abrir(
  WidgetTester tester,
  _Pedidos repo, {
  double escala = 1,
}) async {
  tester.view.physicalSize = Size(escala == 1 ? 390 : 320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => CaseroPedidoScreen(
          pedidoId: 1,
          usuario: const Usuario(
            nombres: 'Rosa',
            celular: '912345678',
            rol: Rol.comerciante,
            puestoId: 1,
          ),
          repository: repo,
        ),
      ),
      GoRoute(
        path: '/casero/inicio/pedido/1/pesar',
        builder: (_, _) => const Scaffold(body: Text('Balanza del pedido')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ver(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: scrollable,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await _ver(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _elegir(
  WidgetTester tester,
  String producto,
  Disponibilidad estado,
) async {
  await _tocar(tester, find.widgetWithText(RevisionProductoCasero, producto));
  await _tocar(
    tester,
    find.widgetWithText(RadioListTile<Disponibilidad>, estado.etiqueta),
  );
}

void main() {
  testWidgets('la tarjeta de revisión se puede activar con teclado', (
    tester,
  ) async {
    var abierta = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: RevisionProductoCasero(
            detalle: const PedidoDetalle(
              id: 100,
              nombre: 'Tomate',
              unidad: UnidadMedida.kg,
              cantidadSolicitada: 1,
              precioEstimadoUnitario: 4,
            ),
            habilitado: true,
            onTap: () => abierta = true,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(abierta, isTrue);
  });

  testWidgets('abrir o cancelar la selección no cambia la disponibilidad', (
    tester,
  ) async {
    final repo = _Pedidos();
    await _abrir(tester, repo);
    await _elegir(tester, 'Tomate', Disponibilidad.disponible);
    expect(repo.guardados, 0);
    await _tocar(tester, find.text('Cancelar'));
    expect(repo.estados[100], Disponibilidad.pendiente);
    expect(repo.guardados, 0);
  });

  testWidgets(
    'el guardado bloquea acciones hasta leer el estado del servidor',
    (tester) async {
      final repo = _Pedidos()..pendiente = Completer<void>();
      await _abrir(tester, repo);
      await _elegir(tester, 'Tomate', Disponibilidad.disponible);
      await _tocar(tester, find.text('Guardar disponibilidad'));
      expect(repo.guardados, 1);
      expect(
        tester
            .widget<RevisionProductoCasero>(find.byType(RevisionProductoCasero))
            .habilitado,
        isFalse,
      );
      await _ver(tester, find.text('Pesar y poner precio'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Pesar y poner precio'),
            )
            .onPressed,
        isNull,
      );
      repo.pendiente!.complete();
      await tester.pumpAndSettle();
      expect(repo.estados[100], Disponibilidad.disponible);
      expect(repo.cargas, 2);
      await _ver(tester, find.byType(RevisionProductoCasero));
      expect(find.text('Lo tengo'), findsOneWidget);
      expect(
        tester
            .widget<RevisionProductoCasero>(find.byType(RevisionProductoCasero))
            .habilitado,
        isTrue,
      );
    },
  );

  testWidgets(
    'un guardado fallido conserva el estado anterior y permite reintentar',
    (tester) async {
      final repo = _Pedidos()..fallarGuardado = true;
      await _abrir(tester, repo);
      await _elegir(tester, 'Tomate', Disponibilidad.sinStock);
      await _tocar(tester, find.text('Guardar disponibilidad'));
      expect(repo.estados[100], Disponibilidad.pendiente);
      expect(
        find.text('No pudimos guardar la disponibilidad.'),
        findsOneWidget,
      );
      repo.fallarGuardado = false;
      await _elegir(tester, 'Tomate', Disponibilidad.disponible);
      await _tocar(tester, find.text('Guardar disponibilidad'));
      expect(repo.estados[100], Disponibilidad.disponible);
      expect(repo.guardados, 2);
    },
  );

  testWidgets('una carga fallida muestra Reintentar y recupera el pedido', (
    tester,
  ) async {
    final repo = _Pedidos()..fallarCarga = true;
    await _abrir(tester, repo);
    expect(find.text('No pudimos actualizar el pedido'), findsOneWidget);
    repo.fallarCarga = false;
    await _tocar(tester, find.text('Reintentar'));
    expect(find.text('Revisa cada producto'), findsOneWidget);
  });

  testWidgets(
    'no permite pesar hasta revisar todo ni si todo quedó sin stock',
    (tester) async {
      final repo = _Pedidos();
      repo.estados[100] = Disponibilidad.sinStock;
      await _abrir(tester, repo);
      await _ver(tester, find.text('Pesar y poner precio'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Pesar y poner precio'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Rechazar pedido'), findsOneWidget);
      repo.estados[100] = Disponibilidad.disponible;
      repo.estados[101] = Disponibilidad.pendiente;
      repo.notificador.value++;
      await tester.pumpAndSettle();
      await _ver(tester, find.text('Pesar y poner precio'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Pesar y poner precio'),
            )
            .onPressed,
        isNull,
      );
      await _elegir(tester, 'Papa', Disponibilidad.sinStock);
      await _tocar(tester, find.text('Guardar disponibilidad'));
      await _tocar(tester, find.text('Pesar y poner precio'));
      expect(find.text('Balanza del pedido'), findsOneWidget);
    },
  );

  testWidgets('revisión y selector se adaptan a 320 con texto al 200%', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _abrir(tester, _Pedidos(), escala: 2);
      await _elegir(tester, 'Tomate', Disponibilidad.reemplazo);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await _tocar(tester, find.text('Cancelar'));
      await _ver(tester, find.text('Pesar y poner precio'));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('los mensajes rápidos se copian sin simular un envío al cliente', (
    tester,
  ) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _abrir(tester, _Pedidos());
    await _tocar(tester, find.text('Ya estoy pesando tu pedido'));
    expect(copiado, 'Ya estoy pesando tu pedido');
    expect(
      find.text(
        'Mensaje copiado. Envíalo al cliente desde tu aplicación de mensajes.',
      ),
      findsOneWidget,
    );
  });
}
