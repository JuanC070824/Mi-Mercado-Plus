import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mimercado_frontend/data/models/cotizacion.dart';
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

class _Pedidos extends PedidosVendedorApiRepository {
  final estados = <int, Disponibilidad>{100: Disponibilidad.disponible};
  final notificador = ValueNotifier(0);
  int cargas = 0;
  int guardados = 0;
  EstadoPedidoPuesto estado = EstadoPedidoPuesto.pesado;
  EstadoCotizacion estadoCotizacion = EstadoCotizacion.enviada;
  bool conCotizacion = true;
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
        cotizacion: conCotizacion
            ? Cotizacion(
                version: 1,
                estado: estadoCotizacion,
                costoEnvio: 5,
                puestos: const [
                  CotizacionPuesto(
                    pedidoPuestoId: 10,
                    nota: 'Maduros',
                    detalles: [
                      CotizacionDetalle(
                        pedidoDetalleId: 100,
                        nombreFinal: 'Tomate de ensalada',
                        cantidadReal: 1.235,
                        precioUnitario: 4,
                      ),
                    ],
                  ),
                ],
              )
            : null,
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
            estado: estado,
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
  Future<void> marcarListo(int id) => _accion(EstadoPedidoPuesto.listo);
  @override
  Future<void> entregarARepartidor(int id) =>
      _accion(EstadoPedidoPuesto.recogido);
  Future<void> _accion(EstadoPedidoPuesto nuevo) async {
    guardados++;
    if (pendiente != null) await pendiente!.future;
    if (fallarGuardado) throw const PedidoException('No se guardó el cambio.');
    estado = nuevo;
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
        .first;
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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await _ver(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('distingue cotización incompleta y muestra pesos exactos y nota', (
    tester,
  ) async {
    final repo = _Pedidos()..estadoCotizacion = EstadoCotizacion.borrador;
    await _abrir(tester, repo);
    await _ver(
      tester,
      find.text(
        'Tu precio está guardado. Esperamos que los otros puestos envíen sus precios.',
      ),
    );
    await _ver(tester, find.text('Tomate de ensalada · 1.235 kg · S/ 4.94'));
    await _ver(tester, find.text('Nota: Maduros'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'actualiza el estado automáticamente y respeta pausa de la aplicación',
    (tester) async {
      final repo = _Pedidos();
      await _abrir(tester, repo);
      final cargas = repo.cargas;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.cargas, cargas);
      repo.estado = EstadoPedidoPuesto.enPreparacion;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.cargas, cargas + 1);
      await _ver(tester, find.text('Ya empaqueté: marcar listo'));
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(repo.cargas, cargas + 2);
    },
  );
  testWidgets('marcar listo requiere confirmación y evita doble envío', (
    tester,
  ) async {
    final repo = _Pedidos()..estado = EstadoPedidoPuesto.enPreparacion;
    await _abrir(tester, repo);
    await _tocar(tester, find.text('Ya empaqueté: marcar listo'));
    await _tocar(tester, find.text('Volver a revisar'));
    expect(repo.guardados, 0);
    await _tocar(tester, find.text('Ya empaqueté: marcar listo'));
    repo.pendiente = Completer<void>();
    await _tocar(tester, find.text('Sí, está lista'));
    expect(repo.guardados, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Ya empaqueté: marcar listo'),
          )
          .onPressed,
      isNull,
    );
    repo.pendiente!.complete();
    await tester.pumpAndSettle();
    expect(repo.estado, EstadoPedidoPuesto.listo);
  });
  testWidgets(
    'entrega exige checklist, identifica al cliente y conserva selección al fallar',
    (tester) async {
      final repo = _Pedidos()..estado = EstadoPedidoPuesto.listo;
      await _abrir(tester, repo);
      await _ver(tester, find.text('Bolsa para entregar'));
      expect(find.textContaining('MM-'), findsNothing);
      await _ver(tester, find.text('Ya se lo entregué'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Ya se lo entregué'),
            )
            .onPressed,
        isNull,
      );
      await _tocar(tester, find.byType(CheckboxListTile));
      await _tocar(tester, find.text('Ya se lo entregué'));
      repo.fallarGuardado = true;
      await _tocar(tester, find.text('Sí, entregué la bolsa'));
      expect(repo.estado, EstadoPedidoPuesto.listo);
      await _ver(tester, find.byType(CheckboxListTile));
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      repo.fallarGuardado = false;
      await _tocar(tester, find.text('Ya se lo entregué'));
      await _tocar(tester, find.text('Sí, entregué la bolsa'));
      await _ver(tester, find.text('¡Bolsa entregada al repartidor!'));
      expect(repo.estado, EstadoPedidoPuesto.recogido);
    },
  );
  testWidgets('sin cotización no habilita entrega de una bolsa vacía', (
    tester,
  ) async {
    final repo = _Pedidos()
      ..estado = EstadoPedidoPuesto.listo
      ..conCotizacion = false;
    await _abrir(tester, repo);
    await _ver(tester, find.text('Ya se lo entregué'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Ya se lo entregué'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'seguimiento y confirmaciones se recorren a 320 px y letra 200%',
    (tester) async {
      final repo = _Pedidos()..estado = EstadoPedidoPuesto.listo;
      await _abrir(tester, repo, escala: 2);
      await _tocar(tester, find.byType(CheckboxListTile));
      await _tocar(tester, find.text('Ya se lo entregué'));
      await _ver(tester, find.text('Sí, entregué la bolsa'));
      expect(tester.takeException(), isNull);
      await _tocar(tester, find.text('Sí, entregué la bolsa'));
      expect(repo.guardados, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

