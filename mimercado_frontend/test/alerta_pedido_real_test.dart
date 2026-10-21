import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:mimercado_frontend/data/repositories/vendedor_inicio_repository.dart';
import 'package:mimercado_frontend/features/canasta/widgets/opcion_elegible.dart';
import 'package:mimercado_frontend/features/casero/screens/casero_inicio_screen.dart';

const _parte = PedidoPuesto(
  id: 10,
  puesto: Puesto(
    id: 1,
    mercadoId: 1,
    nombre: 'Verduras Rosa',
    casero: 'Rosa',
    categoria: CategoriaPuesto.verduras,
    calificacion: 0,
    resenas: 0,
  ),
  codigoBolsa: 'MM-1-1',
  estado: EstadoPedidoPuesto.pendiente,
  parada: 1,
  listaMandado: 'Un atado de culantro',
  detalles: [
    PedidoDetalle(
      id: 100,
      nombre: 'Tomate',
      unidad: UnidadMedida.kg,
      cantidadSolicitada: 2,
      precioEstimadoUnitario: 4,
    ),
  ],
);

class _Pedidos extends PedidosVendedorApiRepository {
  bool aceptado = false;
  bool rechazado = false;
  bool fallarAceptacion = false;
  bool fallarPrimerRechazo = false;
  int aceptaciones = 0;
  int rechazos = 0;
  String? motivo;
  Completer<void>? rechazoPendiente;

  @override
  Future<List<Pedido>> pedidosDePuesto(int puestoId) async => [
    Pedido(
      id: 1,
      codigo: 'MM-1',
      codigoCorto: '1',
      clienteNombre: 'María',
      clienteCelular: '900000001',
      mercadoId: 1,
      estado: EstadoPedido.pendiente,
      metodoPago: MetodoPago.efectivo,
      direccion: 'Dirección de prueba',
      puestos: [_parte],
      costoEnvio: 5,
      historial: [],
      codigoEntrega: '',
      creadoEn: DateTime(2026, 10, 20),
    ),
  ];

  @override
  Future<void> aceptarSubpedido(int id) async {
    expect(id, 10);
    aceptaciones++;
    if (fallarAceptacion) {
      throw const PedidoException('No pudimos aceptar el pedido.');
    }
    aceptado = true;
  }

  @override
  Future<void> rechazarSubpedido(int id, String texto) async {
    expect(id, 10);
    rechazos++;
    motivo = texto;
    if (fallarPrimerRechazo && rechazos == 1) {
      throw const PedidoException('No pudimos guardar el rechazo. Reintenta.');
    }
    if (rechazoPendiente != null) await rechazoPendiente!.future;
    rechazado = true;
  }
}

class _Inicio extends VendedorInicioApiRepository {
  _Inicio(this.pedidos);
  final _Pedidos pedidos;
  int cargas = 0;

  @override
  Future<VendedorInicio> cargar() async {
    cargas++;
    return VendedorInicio(
      puesto: const PuestoVendedor(
        id: 1,
        nombre: 'Verduras Rosa',
        mercado: 'Mercado Santa Rosa',
        categoria: 'Verduras',
        abierto: true,
      ),
      atencion: const AtencionVendedor(nuevos: 1, preparando: 0, listos: 0),
      resumen: const ResumenVendedor(ventas: 0, comision: 0, recibes: 0),
      pedidos: pedidos.aceptado || pedidos.rechazado
          ? []
          : [
              PedidoActivoVendedor(
                id: 1,
                cliente: 'María',
                productos: 1,
                estado: 'pendiente',
                creadoEn: DateTime(2026, 10, 20),
              ),
            ],
    );
  }
}

Future<GoRouter> _abrir(
  WidgetTester tester,
  _Pedidos pedidos, {
  _Inicio? inicio,
  double escala = 1,
}) async {
  tester.view.physicalSize = Size(escala == 1 ? 390 : 320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => CaseroInicioScreen(
          usuario: const Usuario(
            nombres: 'Rosa',
            celular: '912345678',
            rol: Rol.comerciante,
            puestoId: 1,
            sonido: false,
            vibracion: false,
          ),
          repository: inicio ?? _Inicio(pedidos),
          pedidosRepository: pedidos,
        ),
      ),
      GoRoute(
        path: '/casero/inicio/pedido/:id',
        builder: (_, _) => const Scaffold(body: Text('Detalle del pedido')),
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
  return router;
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  final finder = find.text(texto);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la alerta acepta mediante la API antes de abrir el detalle', (
    tester,
  ) async {
    final pedidos = _Pedidos();
    final router = await _abrir(tester, pedidos);
    expect(find.text('¡NUEVO PEDIDO!'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.textContaining('Pedido de '),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('MM-'), findsNothing);
    await _tocar(tester, 'Aceptar pedido');
    expect(pedidos.aceptaciones, 1);
    expect(router.canPop(), isTrue);
    expect(find.text('Detalle del pedido'), findsOneWidget);
  });

  testWidgets('si la API rechaza la aceptación no navega ni simula éxito', (
    tester,
  ) async {
    final pedidos = _Pedidos()..fallarAceptacion = true;
    final router = await _abrir(tester, pedidos);
    await _tocar(tester, 'Aceptar pedido');
    expect(pedidos.aceptado, isFalse);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('No pudimos aceptar el pedido.'), findsOneWidget);
  });

  testWidgets(
    'verlo después no modifica el pedido ni repite la alerta al actualizar',
    (tester) async {
      final pedidos = _Pedidos();
      final inicio = _Inicio(pedidos);
      await _abrir(tester, pedidos, inicio: inicio);
      await _tocar(tester, 'Verlo después');
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(inicio.cargas, greaterThan(1));
      expect(find.text('¡NUEVO PEDIDO!'), findsNothing);
      expect(pedidos.aceptaciones + pedidos.rechazos, 0);
      await _tocar(tester, 'Pedido de María');
      expect(find.text('¡NUEVO PEDIDO!'), findsOneWidget);
      await _tocar(tester, 'Verlo después');
    },
  );

  testWidgets('cancelar el rechazo no envía ninguna acción a la API', (
    tester,
  ) async {
    final pedidos = _Pedidos();
    await _abrir(tester, pedidos);
    await _tocar(tester, 'Rechazar');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Sí, rechazar pedido'),
          )
          .onPressed,
      isNull,
    );
    await _tocar(tester, 'No, volver');
    expect(pedidos.rechazos, 0);
  });

  testWidgets(
    'el rechazo conserva el motivo tras un error y bloquea envíos duplicados',
    (tester) async {
      final pedidos = _Pedidos()..fallarPrimerRechazo = true;
      await _abrir(tester, pedidos);
      await _tocar(tester, 'Rechazar');
      await _tocar(tester, MotivoRechazo.faltaStock.etiqueta);
      await _tocar(tester, 'Sí, rechazar pedido');
      expect(
        find.text('No pudimos guardar el rechazo. Reintenta.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OpcionElegible>(
              find.widgetWithText(
                OpcionElegible,
                MotivoRechazo.faltaStock.etiqueta,
              ),
            )
            .elegida,
        isTrue,
      );
      pedidos.rechazoPendiente = Completer<void>();
      await tester.ensureVisible(find.text('Sí, rechazar pedido'));
      await tester.tap(find.text('Sí, rechazar pedido'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Sí, rechazar pedido'),
            )
            .onPressed,
        isNull,
      );
      expect(pedidos.rechazos, 2);
      pedidos.rechazoPendiente!.complete();
      await tester.pumpAndSettle();
      expect(pedidos.rechazado, isTrue);
      expect(pedidos.motivo, MotivoRechazo.faltaStock.etiqueta);
      expect(find.text('¿Por qué no puedes atenderlo?'), findsNothing);
    },
  );

  testWidgets('la alerta y los motivos se pueden recorrer con texto al 200%', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _abrir(tester, _Pedidos(), escala: 2);
      await _tocar(tester, 'Rechazar');
      await _tocar(tester, MotivoRechazo.muchosPedidos.etiqueta);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await _tocar(tester, 'No, volver');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
