import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/repositories/vendedor_inicio_repository.dart';
import 'package:mimercado_frontend/features/casero/screens/casero_inicio_screen.dart';
import 'package:mimercado_frontend/features/casero/widgets/encabezado_inicio_casero.dart';

const _puesto = PuestoVendedor(
  id: 1,
  nombre: 'Verduras y frutas de Rosa',
  mercado: 'Mercado Santa Rosa',
  categoria: 'Verduras y frutas',
  numero: '12',
  abierto: true,
);

class _InicioPrueba extends VendedorInicioApiRepository {
  final respuesta = Completer<bool>();

  @override
  Future<VendedorInicio> cargar() async => const VendedorInicio(
    puesto: _puesto,
    atencion: AtencionVendedor(nuevos: 0, preparando: 0, listos: 0),
    resumen: ResumenVendedor(ventas: 0, comision: 0, recibes: 0),
  );

  @override
  Future<bool> cambiarAbierto(bool abierto) => respuesta.future;
}

Future<void> _abrirInicio(WidgetTester tester, _InicioPrueba repo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: CaseroInicioScreen(
        usuario: const Usuario(
          nombres: 'Rosa Quispe',
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
  for (final escala in [1.0, 2.0]) {
    testWidgets('cabecera a 320 de ancho con texto al ${escala * 100}%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: EncabezadoInicioCasero(
                  nombre: 'Rosa',
                  puesto: _puesto,
                  guardandoEstado: false,
                  onCambiarEstado: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('¡Hola, Rosa!'), findsOneWidget);
        expect(find.text('Mercado Santa Rosa · Puesto 12'), findsOneWidget);
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('el estado cambia solo después de la confirmación del servidor', (
    tester,
  ) async {
    final repo = _InicioPrueba();
    await _abrirInicio(tester, repo);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Guardando estado del puesto…'), findsOneWidget);
    var control = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(control.onChanged, isNull);
    expect(control.value, isTrue);

    repo.respuesta.complete(false);
    await tester.pumpAndSettle();
    control = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(control.value, isFalse);
    expect(control.onChanged, isNotNull);
    expect(find.text('Puesto cerrado'), findsOneWidget);
    expect(find.text('Guardando estado del puesto…'), findsNothing);
  });

  testWidgets('si falla el guardado conserva el estado y permite reintentar', (
    tester,
  ) async {
    final repo = _InicioPrueba();
    await _abrirInicio(tester, repo);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    repo.respuesta.completeError(
      const VendedorInicioException(
        'No pudimos guardar el estado. Inténtalo de nuevo.',
      ),
    );
    await tester.pumpAndSettle();
    final control = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(control.value, isTrue);
    expect(control.onChanged, isNotNull);
    expect(find.text('Puesto abierto'), findsOneWidget);
    expect(
      find.textContaining('No pudimos guardar el estado.'),
      findsOneWidget,
    );
  });
}
