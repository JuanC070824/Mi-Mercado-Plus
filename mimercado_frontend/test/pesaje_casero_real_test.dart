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
import 'package:mimercado_frontend/features/casero/screens/pesar_screen.dart';

class _Pedidos extends PedidosVendedorApiRepository {
  final estados = <int, Disponibilidad>{100: Disponibilidad.disponible};
  final notificador = ValueNotifier(0);
  int cargas = 0;
  int guardados = 0;
  bool fallarGuardado = false;
  UnidadMedida unidad = UnidadMedida.kg;
  List<CotizacionDetalle>? enviado;
  String? notaEnviada;
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
                  unidad: unidad,
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
  Future<void> enviarPrecioFinal(
    int id,
    List<CotizacionDetalle> detalles, {
    String? nota,
  }) async {
    guardados++;
    enviado = detalles;
    notaEnviada = nota;
    if (pendiente != null) await pendiente!.future;
    if (fallarGuardado) {
      throw const PedidoException('No pudimos guardar el precio.');
    }
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
    initialLocation: '/casero/inicio/pedido/1/pesar',
    routes: [
      GoRoute(
        path: '/casero/inicio/pedido/1',
        builder: (_, _) => const Scaffold(body: Text('Detalle del pedido')),
        routes: [
          GoRoute(
            path: 'pesar',
            builder: (_, _) => PesarScreen(
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
        ],
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
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await _ver(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String clave, String texto) async {
  final finder = find.byKey(ValueKey(clave));
  await _ver(tester, finder);
  await tester.enterText(finder, texto);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

final _enviar = find.widgetWithText(FilledButton, 'Enviar precio final');
final _confirmar = find.widgetWithText(FilledButton, 'Confirmar y enviar');

void main() {
  testWidgets(
    'confirma el peso exacto y precio, excluye sin stock y guarda nota',
    (tester) async {
      final repo = _Pedidos()..estados[101] = Disponibilidad.sinStock;
      await _abrir(tester, repo);
      await _escribir(tester, 'cantidad_100', '1,235');
      await _escribir(tester, 'precio_100', '5');
      final nota = find.widgetWithText(TextFormField, 'Nota para el cliente');
      await _ver(tester, nota);
      await tester.enterText(nota, '  Maduros  ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _tocar(tester, _enviar);
      expect(repo.guardados, 0);
      expect(find.text('Tomate: 1.235 kg · S/ 6.18'), findsOneWidget);
      await _tocar(tester, _confirmar);
      expect(repo.guardados, 1);
      expect(repo.enviado!.single.cantidadReal, 1.235);
      expect(repo.enviado!.single.precioUnitario, 5);
      expect(repo.notaEnviada, 'Maduros');
      expect(find.text('Detalle del pedido'), findsOneWidget);
    },
  );

  testWidgets('cancelar la confirmación conserva los cambios', (tester) async {
    final repo = _Pedidos();
    await _abrir(tester, repo);
    await _escribir(tester, 'cantidad_100', '2.250');
    await _tocar(tester, _enviar);
    await _tocar(tester, find.text('Volver a corregir'));
    await _ver(tester, find.byKey(const ValueKey('cantidad_100')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cantidad_100')))
          .controller!
          .text,
      '2.250',
    );
    expect(repo.guardados, 0);
  });

  testWidgets(
    'rechaza cero y precisión inválida aunque el campo quede fuera de pantalla',
    (tester) async {
      final repo = _Pedidos();
      await _abrir(tester, repo);
      for (final valor in ['0', '-1', '1.2345', 'abc']) {
        await _escribir(tester, 'cantidad_100', valor);
        await _tocar(tester, _enviar);
        expect(find.text('Confirmar precio final'), findsNothing);
        expect(repo.guardados, 0);
      }
      await _escribir(tester, 'cantidad_100', '1');
      await _escribir(tester, 'precio_100', '0');
      await _tocar(tester, _enviar);
      expect(find.text('Confirmar precio final'), findsNothing);
      expect(repo.guardados, 0);
    },
  );

  testWidgets('las unidades no permiten fracciones', (tester) async {
    final repo = _Pedidos()..unidad = UnidadMedida.unidad;
    await _abrir(tester, repo);
    await _escribir(tester, 'cantidad_100', '1.5');
    await _tocar(tester, _enviar);
    expect(find.text('Confirmar precio final'), findsNothing);
    await _escribir(tester, 'cantidad_100', '2');
    await _tocar(tester, _enviar);
    expect(find.text('Confirmar precio final'), findsOneWidget);
  });

  testWidgets('exige el nombre real del reemplazo', (tester) async {
    final repo = _Pedidos()..estados[100] = Disponibilidad.reemplazo;
    await _abrir(tester, repo);
    await _tocar(tester, _enviar);
    expect(find.text('Confirmar precio final'), findsNothing);
    await _escribir(tester, 'reemplazo_100', 'Tomate de ensalada');
    await _tocar(tester, _enviar);
    await _tocar(tester, _confirmar);
    expect(repo.enviado!.single.nombreFinal, 'Tomate de ensalada');
  });

  testWidgets('conserva datos al fallar y bloquea envíos simultáneos', (
    tester,
  ) async {
    final repo = _Pedidos()..fallarGuardado = true;
    await _abrir(tester, repo);
    await _escribir(tester, 'precio_100', '7.50');
    await _tocar(tester, _enviar);
    await _tocar(tester, _confirmar);
    expect(find.text('No pudimos guardar el precio.'), findsOneWidget);
    expect(repo.enviado!.single.precioUnitario, 7.5);
    repo.fallarGuardado = false;
    repo.pendiente = Completer<void>();
    await _tocar(tester, _enviar);
    await _tocar(tester, _confirmar);
    expect(repo.guardados, 2);
    expect(tester.widget<FilledButton>(_enviar).onPressed, isNull);
    repo.pendiente!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Detalle del pedido'), findsOneWidget);
  });

  testWidgets('permite reintentar la carga y bloquea productos sin revisar', (
    tester,
  ) async {
    final repo = _Pedidos()..fallarCarga = true;
    await _abrir(tester, repo);
    expect(find.text('No pudimos cargar el pesaje'), findsOneWidget);
    repo.fallarCarga = false;
    repo.estados[100] = Disponibilidad.pendiente;
    await _tocar(tester, find.text('Reintentar'));
    expect(find.text('Falta revisar productos'), findsOneWidget);
    expect(_enviar, findsNothing);
  });

  testWidgets('pesaje y confirmación caben a 320 px con texto al 200 %', (
    tester,
  ) async {
    final repo = _Pedidos()..estados[100] = Disponibilidad.reemplazo;
    await _abrir(tester, repo, escala: 2);
    await _escribir(tester, 'reemplazo_100', 'Tomate de ensalada');
    await _escribir(tester, 'cantidad_100', '1.125');
    await _escribir(tester, 'precio_100', '4.50');
    await _tocar(tester, _enviar);
    await _ver(tester, _confirmar);
    expect(tester.getSize(_confirmar).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await _tocar(tester, _confirmar);
    expect(repo.guardados, 1);
    expect(tester.takeException(), isNull);
  });
}
