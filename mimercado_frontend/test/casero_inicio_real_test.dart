import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/features/casero/screens/casero_inicio_screen.dart';

void main() {
  testWidgets('muestra el estado real cuando el vendedor aún no tiene puesto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CaseroInicioScreen(
          usuario: Usuario(
            nombres: 'Gabriel',
            celular: '910023101',
            rol: Rol.comerciante,
          ),
        ),
      ),
    );

    expect(find.text('¡Hola, Gabriel!'), findsOneWidget);
    expect(find.text('Espacio para la foto de tu puesto'), findsOneWidget);
    expect(find.text('Aún no tienes un puesto'), findsOneWidget);
    expect(find.textContaining('Doña Rosa'), findsNothing);
    expect(find.textContaining('Pedido de María'), findsNothing);
  });
}
