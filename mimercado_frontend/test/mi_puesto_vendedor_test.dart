import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/state/accesibilidad_state.dart';
import 'package:mimercado_frontend/core/state/preferencias_vendedor_state.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/repositories/auth_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/puesto_vendedor_repository.dart';
import 'package:mimercado_frontend/features/casero/screens/mi_puesto_screen.dart';

const _usuario = Usuario(
  nombres: 'Rosa',
  celular: '900000001',
  rol: Rol.comerciante,
  puestoId: 1,
);
const _mercado = MercadoParaPuesto(
  id: 1,
  nombre: 'Mercado Santa Rosa',
  direccion: 'Av. Santa Rosa 123',
);
const _categoria = CategoriaParaPuesto(id: 1, nombre: 'Verduras y frutas');
const _puesto = PuestoDelVendedor(
  id: 1,
  nombre: 'Verdulería Rosa',
  numero: 'A-12',
  mercado: _mercado,
  categoria: _categoria,
  abierto: true,
  horarios: ['Lunes: 06:00–14:00'],
  contactoBilletera: '900000001',
);

class _Preferencias extends AuthApiRepository {
  @override
  Future<Usuario> preferenciasVendedor(
    Usuario u, {
    bool guardar = false,
  }) async => u;
}

class _Puesto extends PuestoVendedorApiRepository {
  int guardados = 0;
  bool fallar = false;
  Completer<void>? pendiente;
  String? nombreGuardado;
  @override
  Future<DatosPuestoVendedor> cargar() async => const DatosPuestoVendedor(
    mercados: [_mercado],
    categorias: [_categoria],
    puesto: _puesto,
  );
  @override
  Future<PuestoDelVendedor> guardar({
    required int? puestoId,
    required int mercadoId,
    required int categoriaId,
    required String nombre,
    required String numero,
    required String referencia,
  }) async {
    guardados++;
    if (pendiente != null) await pendiente!.future;
    if (fallar) throw const PuestoVendedorException('No se guardó el puesto.');
    nombreGuardado = nombre;
    return PuestoDelVendedor(
      id: 1,
      nombre: nombre,
      numero: numero,
      mercado: _mercado,
      categoria: _categoria,
      abierto: true,
    );
  }
}

Future<void> _abrir(WidgetTester t, _Puesto repo, {double escala = 1}) async {
  t.view.physicalSize = const Size(320, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(
          ctx,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: MiPuestoScreen(
        usuario: _usuario,
        onPuestoGuardado: (_) {},
        repository: repo,
        preferenciasRepository: _Preferencias(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _ver(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Future<void> _tocar(WidgetTester t, Finder f) async {
  await _ver(t, f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  tearDown(() {
    PreferenciasVendedorState.limpiar();
    AccesibilidadState.letraGrande.value = false;
  });
  testWidgets('muestra información real y guarda sin solicitudes duplicadas', (
    t,
  ) async {
    final repo = _Puesto()..pendiente = Completer<void>();
    await _abrir(t, repo);
    await _ver(t, find.text('Lunes: 06:00–14:00'));
    await _ver(t, find.text('Yape / Plin: 900000001'));
    final nombre = find.byType(TextFormField).first;
    await _ver(t, nombre);
    await t.enterText(nombre, 'Nuevo nombre');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await _tocar(t, find.text('Guardar cambios'));
    expect(repo.guardados, 1);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Guardando puesto…'),
          )
          .onPressed,
      isNull,
    );
    repo.pendiente!.complete();
    await t.pumpAndSettle();
    expect(repo.nombreGuardado, 'Nuevo nombre');
  });
  testWidgets('error de guardado conserva el formulario y permite reintentar', (
    t,
  ) async {
    final repo = _Puesto()..fallar = true;
    await _abrir(t, repo);
    final nombre = find.byType(TextFormField).first;
    await _ver(t, nombre);
    await t.enterText(nombre, 'Nombre corregido');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await _tocar(t, find.text('Guardar cambios'));
    expect(find.text('No se guardó el puesto.'), findsOneWidget);
    repo.fallar = false;
    await _tocar(t, find.text('Guardar cambios'));
    expect(repo.nombreGuardado, 'Nombre corregido');
  });
  testWidgets(
    'información, preferencias y formulario se recorren con letra al 200%',
    (t) async {
      final repo = _Puesto();
      await _abrir(t, repo, escala: 2);
      await _ver(t, find.text('Cómo te avisamos y cómo lees'));
      await _ver(t, find.text('Lunes: 06:00–14:00'));
      await _ver(t, find.text('Referencia para encontrar el puesto'));
      await _ver(t, find.text('Guardar cambios'));
      expect(
        t.getSize(find.widgetWithText(FilledButton, 'Guardar cambios')).height,
        greaterThanOrEqualTo(48),
      );
      expect(t.takeException(), isNull);
    },
  );
}
