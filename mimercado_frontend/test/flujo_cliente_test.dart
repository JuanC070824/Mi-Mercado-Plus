import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/data/repositories/canasta_repository.dart';

import 'ayuda_pruebas.dart';

void main() {
  setUp(() => CanastaRepositoryMock.instancia.vaciar());

  testWidgets('C2: María abre Doña Rosa, agrega tomate y la barra muestra el total',
      (tester) async {
    await entrarComo(tester, perfil: 'Cliente', celular: '987654321');
    await tocar(tester, find.text('Doña Rosa Verdulería'));

    expect(find.text('Tomate'), findsOneWidget);

    await tocar(tester, find.text('Agregar 0.5 kg').first);
    await tocar(tester, find.bySemanticsLabel('Agregar 0.5 kg de Tomate'));

    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('Subtotal S/ 4.00'), findsOneWidget);
    expect(find.text('Ver canasta'), findsOneWidget);
    expect(CanastaRepositoryMock.instancia.canasta.value.totalProductos, 4.00);

    // La Zanahoria está al final de la lista y no se puede comprar.
    await tester.scrollUntilVisible(find.text('Agotado por hoy'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Agotado por hoy'), findsOneWidget);
  });
}
