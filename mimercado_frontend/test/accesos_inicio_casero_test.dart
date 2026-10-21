import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/features/casero/widgets/accesos_inicio_casero.dart';

void main() {
  testWidgets(
    'los accesos se pueden activar con teclado y tienen área amplia',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var pedidos = 0;
        var catalogo = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: AccesosInicioCasero(
                onVerPedidos: () => pedidos++,
                onVerCatalogo: () => catalogo++,
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(pedidos, 1);
        expect(catalogo, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(catalogo, 1);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'a 320 de ancho y texto al 200% los accesos se apilan sin recortes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
              padding: const EdgeInsets.all(14),
              child: AccesosInicioCasero(
                onVerPedidos: () {},
                onVerCatalogo: () {},
              ),
            ),
          ),
        ),
      );

      final pedidos = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Mis pedidos'),
      );
      final catalogo = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Mi catálogo'),
      );
      expect(catalogo.top, greaterThan(pedidos.bottom));
      expect(pedidos.width, 292);
      expect(tester.takeException(), isNull);
    },
  );
}
