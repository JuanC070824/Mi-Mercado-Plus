import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/producto.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_repository.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_vendedor_api_repository.dart';
import 'package:mimercado_frontend/features/casero/screens/catalogo_casero_screen.dart';

class _Catalogo extends CatalogoVendedorApiRepository {
  final productos = <Producto>[
    const Producto(
      id: 1,
      puestoId: 1,
      nombre: 'Tomate',
      unidad: UnidadMedida.kg,
      precioUnitario: 4,
    ),
    const Producto(
      id: 2,
      puestoId: 1,
      nombre: 'Papa',
      unidad: UnidadMedida.kg,
      precioUnitario: 3,
      disponible: false,
    ),
  ];
  int guardados = 0;
  bool fallar = false;
  bool fallarCarga = false;
  Completer<void>? pendiente;
  Producto? recibido;
  @override
  Future<List<Producto>> cargar() async {
    if (fallarCarga) {
      throw const CatalogoException('No se pudo cargar el catálogo.');
    }
    return productos.toList();
  }

  Future<Producto> _guardar(Producto producto) async {
    guardados++;
    recibido = producto;
    if (pendiente != null) await pendiente!.future;
    if (fallar) {
      throw const CatalogoException('No se pudo guardar el producto.');
    }
    final guardado = producto.id == 0
        ? Producto(
            id: 3,
            puestoId: 1,
            nombre: producto.nombre,
            unidad: producto.unidad,
            precioUnitario: producto.precioUnitario,
            imagen: producto.imagen,
          )
        : producto;
    productos.removeWhere((p) => p.id == guardado.id);
    productos.add(guardado);
    return guardado;
  }

  @override
  Future<Producto> crear(Producto p) => _guardar(p);
  @override
  Future<Producto> actualizar(Producto p) => _guardar(p);
}

Future<void> _abrir(
  WidgetTester tester,
  _Catalogo repo, {
  double escala = 1,
}) async {
  tester.view.physicalSize = Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(
          ctx,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: CatalogoCaseroScreen(
        usuario: const Usuario(
          nombres: 'Rosa',
          celular: '900000001',
          rol: Rol.comerciante,
          puestoId: 1,
        ),
        repository: repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ver(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scroll = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: scroll,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester t, Finder f) async {
  await _ver(t, f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _escribir(WidgetTester t, String clave, String valor) async {
  final f = find.byKey(ValueKey(clave));
  await _ver(t, f);
  await t.enterText(f, valor);
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'edición conserva el precio escrito cuando falla y permite reintentar',
    (t) async {
      final repo = _Catalogo()..fallar = true;
      await _abrir(t, repo);
      await _tocar(t, find.byTooltip('Editar Tomate'));
      await _escribir(t, 'precio_producto', '5,50');
      await _tocar(t, find.text('Guardar producto'));
      expect(find.text('No se pudo guardar el producto.'), findsOneWidget);
      await _ver(t, find.byKey(const ValueKey('precio_producto')));
      expect(
        t
            .widget<TextFormField>(
              find.byKey(const ValueKey('precio_producto')),
            )
            .controller!
            .text,
        '5,50',
      );
      repo.fallar = false;
      await _tocar(t, find.text('Guardar producto'));
      await _ver(t, find.text('S/ 5.50 / kg'));
      expect(repo.guardados, 2);
    },
  );
  testWidgets(
    'crear valida nombre y decimales y bloquea guardar mientras espera',
    (t) async {
      final repo = _Catalogo();
      await _abrir(t, repo);
      await _tocar(t, find.text('Añadir producto'));
      await _tocar(t, find.text('Guardar producto'));
      expect(repo.guardados, 0);
      await _escribir(t, 'nombre_producto', 'Limón');
      await _escribir(t, 'precio_producto', 'NaN');
      await _tocar(t, find.text('Guardar producto'));
      expect(repo.guardados, 0);
      await _escribir(t, 'precio_producto', '2.555');
      await _tocar(t, find.text('Guardar producto'));
      expect(repo.guardados, 0);
      await _escribir(t, 'precio_producto', '2.50');
      repo.pendiente = Completer<void>();
      await _tocar(t, find.text('Guardar producto'));
      expect(repo.guardados, 1);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardando producto…'),
            )
            .onPressed,
        isNull,
      );
      repo.pendiente!.complete();
      await t.pumpAndSettle();
      await _ver(t, find.text('Limón'));
      expect(repo.recibido!.precioUnitario, 2.5);
    },
  );
  testWidgets(
    'disponibilidad bloquea cambios concurrentes y revierte al fallar',
    (t) async {
      final repo = _Catalogo()
        ..fallar = true
        ..pendiente = Completer<void>();
      await _abrir(t, repo);
      await _tocar(t, find.byType(SwitchListTile).first);
      expect(repo.guardados, 1);
      await _ver(t, find.byType(SwitchListTile).last);
      for (final w in t.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      )) {
        expect(w.onChanged, isNull);
      }
      repo.pendiente!.complete();
      await t.pumpAndSettle();
      expect(repo.productos.firstWhere((p) => p.id == 1).disponible, isTrue);
    },
  );
  testWidgets('carga se puede reintentar y filtro muestra agotados', (t) async {
    final repo = _Catalogo()..fallarCarga = true;
    await _abrir(t, repo);
    repo.fallarCarga = false;
    await _tocar(t, find.text('Reintentar'));
    await _tocar(t, find.widgetWithText(ChoiceChip, 'Agotados'));
    expect(find.text('Tomate'), findsNothing);
    expect(find.text('Papa'), findsOneWidget);
  });
  testWidgets('catálogo y formulario caben a 320 px con texto 200%', (t) async {
    final repo = _Catalogo();
    await _abrir(t, repo, escala: 2);
    expect(t.takeException(), isNull);
    await _tocar(t, find.text('Añadir producto'));
    await _escribir(t, 'nombre_producto', 'Limón');
    await _escribir(t, 'precio_producto', '3,50');
    await _tocar(t, find.text('Guardar producto'));
    expect(repo.guardados, 1);
    expect(t.takeException(), isNull);
  });
}
