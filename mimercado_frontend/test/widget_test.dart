import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';

void main() {
  testWidgets('la app abre en la bienvenida con los 3 perfiles', (tester) async {
    final vista = tester.view;
    vista.physicalSize = const Size(1080, 2400);
    vista.devicePixelRatio = 3;
    addTearDown(vista.reset);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: appRouter),
    );
    await tester.pumpAndSettle();

    expect(find.text('Soy:'), findsOneWidget);
    for (final perfil in ['Cliente', 'Repartidor', 'Comerciante']) {
      expect(find.text(perfil), findsOneWidget);
    }
  });
}
