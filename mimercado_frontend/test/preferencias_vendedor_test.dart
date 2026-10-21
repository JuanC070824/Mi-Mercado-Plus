import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/app.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/core/state/accesibilidad_state.dart';
import 'package:mimercado_frontend/core/state/preferencias_vendedor_state.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/repositories/auth_api_repository.dart';
import 'package:mimercado_frontend/features/casero/widgets/preferencias_vendedor.dart';

const _usuario = Usuario(
  nombres: 'Rosa',
  celular: '900000001',
  rol: Rol.comerciante,
  puestoId: 1,
);

class _Preferencias extends AuthApiRepository {
  Usuario actual = _usuario;
  bool fallar = false;
  bool fallarCarga = false;
  int guardados = 0;
  Completer<void>? pendiente;
  @override
  Future<Usuario> preferenciasVendedor(
    Usuario usuario, {
    bool guardar = false,
  }) async {
    if (!guardar) {
      if (fallarCarga) throw StateError('Sin conexión');
      return actual;
    }
    guardados++;
    if (pendiente != null) await pendiente!.future;
    if (fallar) throw StateError('Sin conexión');
    return actual = usuario;
  }
}

Future<void> _abrir(
  WidgetTester t,
  _Preferencias repo, {
  double escala = 1,
}) async {
  t.view.physicalSize = const Size(320, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escala)),
          child: SingleChildScrollView(
            child: PreferenciasVendedor(usuario: _usuario, repository: repo),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _tocar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'la sesión restaura letra grande sin actualizar ancestros durante build',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MiMercadoApp());
      appRouter.go(
        '/casero/inicio',
        extra: _usuario.copyWith(letraGrande: true),
      );
      await t.pumpAndSettle();
      expect(AccesibilidadState.letraGrande.value, isTrue);
      expect(t.takeException(), isNull);
      appRouter.go('/');
      await t.pumpAndSettle();
    },
  );
  tearDown(() {
    PreferenciasVendedorState.limpiar();
    AccesibilidadState.letraGrande.value = false;
    SesionState.cerrar();
  });
  test(
    'API guarda y lee las tres preferencias sin modificar otros datos',
    () async {
      SesionState.iniciar(token: 'prueba', expiresIn: 3600);
      var guardados = 0;
      final repo = AuthApiRepository(
        baseUrl: 'https://example.test',
        client: MockClient((r) async {
          expect(r.url.path, '/api/auth/me/');
          expect(r.headers['Authorization'], 'Bearer prueba');
          if (r.method == 'PATCH') {
            guardados++;
            expect(jsonDecode(r.body), {
              'letra_grande': true,
              'sonido': false,
              'vibracion': false,
            });
          }
          return http.Response(
            jsonEncode({
              'letra_grande': true,
              'sonido': false,
              'vibracion': false,
            }),
            200,
          );
        }),
      );
      final guardado = await repo.preferenciasVendedor(
        _usuario.copyWith(letraGrande: true, sonido: false, vibracion: false),
        guardar: true,
      );
      final leido = await repo.preferenciasVendedor(_usuario);
      expect(guardados, 1);
      expect(guardado.puestoId, 1);
      expect(leido.letraGrande, isTrue);
      expect(leido.sonido, isFalse);
    },
  );
  testWidgets(
    'solo aplica preferencias confirmadas y bloquea peticiones simultáneas',
    (t) async {
      final repo = _Preferencias()..pendiente = Completer<void>();
      await _abrir(t, repo);
      await _tocar(t, find.byType(Switch).at(0));
      expect(repo.guardados, 1);
      expect(AccesibilidadState.letraGrande.value, isFalse);
      for (final w in t.widgetList<Switch>(find.byType(Switch))) {
        expect(w.onChanged, isNull);
      }
      repo.pendiente!.complete();
      await t.pumpAndSettle();
      expect(AccesibilidadState.letraGrande.value, isTrue);
      expect(PreferenciasVendedorState.de(_usuario).letraGrande, isTrue);
      await _tocar(t, find.byType(Switch).at(1));
      expect(PreferenciasVendedorState.de(_usuario).sonido, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      PreferenciasVendedorState.limpiar();
      AccesibilidadState.letraGrande.value = false;
      await _abrir(t, repo);
      expect(AccesibilidadState.letraGrande.value, isTrue);
      expect(t.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    },
  );
  testWidgets('un error no muestra la preferencia como guardada', (t) async {
    final repo = _Preferencias()..fallar = true;
    await _abrir(t, repo);
    await _tocar(t, find.byType(Switch).first);
    expect(AccesibilidadState.letraGrande.value, isFalse);
    expect(t.widget<Switch>(find.byType(Switch).first).value, isFalse);
    repo.fallar = false;
    await _tocar(t, find.byType(Switch).first);
    expect(AccesibilidadState.letraGrande.value, isTrue);
  });
  testWidgets('permite reintentar la carga y ajustes caben con texto al 200%', (
    t,
  ) async {
    final repo = _Preferencias()..fallarCarga = true;
    await _abrir(t, repo, escala: 2);
    expect(t.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
    repo.fallarCarga = false;
    await _tocar(t, find.text('Volver a cargar preferencias'));
    await _tocar(t, find.byType(Switch).last);
    expect(repo.actual.vibracion, isFalse);
    expect(t.takeException(), isNull);
    // La opción no puede reducir una escala de texto mayor elegida en el sistema.
    expect(
      const TextScaler.linear(
        2,
      ).clamp(minScaleFactor: AccesibilidadState.factorLetraGrande).scale(20),
      40,
    );
  });
}
