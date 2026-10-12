import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/utils/formato.dart';
import 'package:mimercado_frontend/core/widgets/encabezado_simple.dart';
import 'package:mimercado_frontend/core/widgets/soporte_dialog.dart';
import 'package:mimercado_frontend/data/models/producto.dart';

void main() {
  testWidgets('el botón Soporte abre "¿Necesitas ayuda?" con el número',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: EncabezadoSimple(titulo: 'Mi canasta')),
    ));
    await tester.tap(find.text('Soporte'));
    await tester.pumpAndSettle();

    expect(find.text('¿Necesitas ayuda?'), findsOneWidget);
    expect(find.text(numeroSoporte), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Necesitas ayuda?'), findsNothing);
  });

  test('formatos de montos y cantidades', () {
    expect(soles(15.8), 'S/ 15.80');
    expect(cantidadConUnidad(1.5, UnidadMedida.kg), '1.5 kg');
    expect(cantidadConUnidad(2, UnidadMedida.atado), '2 atados');
    expect(cantidadConUnidad(1, UnidadMedida.atado), '1 atado');
  });
}
