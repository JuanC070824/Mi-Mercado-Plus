import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/cotizacion.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/models/producto.dart';
import 'package:mimercado_frontend/data/models/puesto.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_vendedor_api_repository.dart';
import 'package:mimercado_frontend/features/casero/screens/mis_pedidos_casero_screen.dart';
import 'package:mimercado_frontend/features/casero/widgets/tarjeta_pedido_casero.dart';

const _puesto = Puesto(
  id: 1,
  mercadoId: 1,
  nombre: 'Verduras Rosa',
  casero: 'Rosa',
  categoria: CategoriaPuesto.verduras,
  calificacion: 0,
  resenas: 0,
);

Pedido _pedido(int id, EstadoPedidoPuesto estado, {bool cotizado = false}) {
  return Pedido(
    id: id,
    codigo: 'MM-$id',
    codigoCorto: '$id',
    clienteNombre: 'María del Pilar',
    clienteCelular: '900000001',
    mercadoId: 1,
    estado: EstadoPedido.enCamino,
    metodoPago: MetodoPago.efectivo,
    direccion: 'Dirección de prueba',
    costoEnvio: 5,
    historial: const [],
    codigoEntrega: '',
    creadoEn: DateTime(2026, 10, 20, 10),
    puestos: [
      PedidoPuesto(
        id: id * 10,
        puesto: _puesto,
        codigoBolsa: 'MM-$id-1',
        estado: estado,
        parada: 1,
        listaMandado: 'Un atado de culantro',
        detalles: const [
          PedidoDetalle(
            id: 100,
            nombre: 'Tomate',
            unidad: UnidadMedida.kg,
            cantidadSolicitada: 2,
            precioEstimadoUnitario: 4,
          ),
        ],
      ),
      PedidoPuesto(
        id: id * 10 + 1,
        puesto: const Puesto(
          id: 2,
          mercadoId: 1,
          nombre: 'Carnes',
          casero: 'Juan',
          categoria: CategoriaPuesto.carnes,
          calificacion: 0,
          resenas: 0,
        ),
        codigoBolsa: 'MM-$id-2',
        estado: estado,
        parada: 2,
        detalles: const [
          PedidoDetalle(
            id: 200,
            nombre: 'Carne',
            unidad: UnidadMedida.kg,
            cantidadSolicitada: 2,
            precioEstimadoUnitario: 99,
          ),
        ],
      ),
    ],
    cotizacion: cotizado
        ? Cotizacion(
            version: 1,
            estado: EstadoCotizacion.enviada,
            costoEnvio: 5,
            puestos: [
              CotizacionPuesto(
                pedidoPuestoId: id * 10,
                detalles: const [
                  CotizacionDetalle(
                    pedidoDetalleId: 100,
                    nombreFinal: 'Tomate',
                    cantidadReal: 1.5,
                    precioUnitario: 6,
                  ),
                ],
              ),
            ],
          )
        : null,
  );
}

class _PedidosPrueba extends PedidosVendedorApiRepository {
  _PedidosPrueba({this.fallarPrimera = false});
  final bool fallarPrimera;
  int llamadas = 0;

  @override
  Future<List<Pedido>> pedidosDePuesto(int puestoId) async {
    llamadas++;
    if (fallarPrimera && llamadas == 1) {
      throw const PedidoException('No hay conexión. Vuelve a intentarlo.');
    }
    return [
      _pedido(1, EstadoPedidoPuesto.pendiente),
      _pedido(2, EstadoPedidoPuesto.enPreparacion),
      _pedido(3, EstadoPedidoPuesto.recogido),
    ];
  }
}

Future<void> _abrirLista(
  WidgetTester tester,
  _PedidosPrueba repo, {
  double escala = 1,
}) async {
  tester.view.physicalSize = Size(escala == 1 ? 390 : 320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: MisPedidosCaseroScreen(
        usuario: const Usuario(
          nombres: 'Rosa',
          celular: '912345678',
          rol: Rol.comerciante,
          puestoId: 1,
        ),
        repository: repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('las pestañas siguen utilizables a 320 con texto al 200%', (
    tester,
  ) async {
    await _abrirLista(tester, _PedidosPrueba(), escala: 2);
    final entregados = find.text('Entregados (1)');
    await tester.ensureVisible(entregados);
    await tester.pumpAndSettle();
    await tester.tap(entregados);
    await tester.pumpAndSettle();
    expect(
      DefaultTabController.of(tester.element(find.byType(TabBar))).index,
      2,
    );
    await tester.scrollUntilVisible(
      find.text('Recogido'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    expect(find.text('Recogido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las pestañas separan nuevos, en curso y bolsas recogidas', (
    tester,
  ) async {
    await _abrirLista(tester, _PedidosPrueba());
    expect(find.text('Nuevo pedido'), findsOneWidget);
    await tester.tap(find.text('En curso (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Empaquetando'), findsOneWidget);
    final entregados = find.text('Entregados (1)');
    await tester.ensureVisible(entregados);
    await tester.tap(entregados);
    await tester.pumpAndSettle();
    expect(find.text('Recogido'), findsOneWidget);
    expect(
      find.textContaining('Bolsas entregadas al repartidor.'),
      findsOneWidget,
    );
  });

  testWidgets('el error de carga permite reintentar y recuperar la lista', (
    tester,
  ) async {
    final repo = _PedidosPrueba(fallarPrimera: true);
    await _abrirLista(tester, repo);
    expect(find.text('No pudimos cargar tus pedidos'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, 2);
    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('la tarjeta accesible muestra solo el estimado del puesto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var abierto = false;
    final pedido = _pedido(1, EstadoPedidoPuesto.pendiente);
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TarjetaPedidoCasero(
                pedido: pedido,
                parte: pedido.puestos.first,
                onTap: () => abierto = true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Estimado de tu puesto'), findsOneWidget);
      expect(find.text('S/ 8.00'), findsOneWidget);
      expect(find.text('Con lista de mandado'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(abierto, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('la tarjeta distingue el precio final publicado del estimado', (
    tester,
  ) async {
    final pedido = _pedido(1, EstadoPedidoPuesto.pesado, cotizado: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: TarjetaPedidoCasero(
            pedido: pedido,
            parte: pedido.puestos.first,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Precio final de tu puesto'), findsOneWidget);
    expect(find.text('S/ 9.00'), findsOneWidget);
    expect(find.text('S/ 8.00'), findsNothing);
  });
}
